
#include <getopt.h>
#include <sys/uio.h>
#include <unistd.h>
#include "cmds.h"
#include "libbcachefs/error.h"
#include "libbcachefs.h"
#include "libbcachefs/super.h"
#include "tools-util.h"

static void usage(void)
{
	puts("bcachefs fsck - filesystem check and repair\n"
	     "Usage: bcachefs fsck [OPTION]... <devices>\n"
	     "\n"
	     "Options:\n"
	     "  -p                      Automatic repair (no questions)\n"
	     "  -n                      Don't repair, only check for errors\n"
	     "  -y                      Assume \"yes\" to all questions\n"
	     "  -f                      Force checking even if filesystem is marked clean\n"
	     "  -r, --ratelimit_errors  Don't display more than 10 errors of a given type\n"
	     "  -R, --reconstruct_alloc Reconstruct the alloc btree\n"
	     "  -v                      Be verbose\n"
	     "  -h, --help              Display this help and exit\n"
	     "Report bugs to <linux-bcachefs@vger.kernel.org>");
}

static void setnonblocking(int fd)
{
	int flags = fcntl(fd, F_GETFL);
	if (fcntl(fd, F_SETFL, flags|O_NONBLOCK))
		die("fcntl error: %m");
}

static int do_splice(int rfd, int wfd)
{
	char buf[4096];

	int r = read(rfd, buf, sizeof(buf));
	if (r < 0 && errno == EAGAIN)
		return 0;
	if (r < 0)
		return r;
	if (!r)
		return 1;
	if (write(wfd, buf, r) != r)
		die("write error");
	return 0;
}

static int fsck_online(const char *dev_path)
{
	int dev_idx;
	struct bchfs_handle fs = bchu_fs_open_by_dev(dev_path, &dev_idx);

	struct bch_ioctl_fsck_online fsck = { 0 };

	int fsck_fd = ioctl(fs.ioctl_fd, BCH_IOCTL_FSCK_ONLINE, &fsck);
	if (fsck_fd < 0)
		die("BCH_IOCTL_FSCK_ONLINE error: %s", bch2_err_str(fsck_fd));

	setnonblocking(STDIN_FILENO);
	setnonblocking(fsck_fd);

	while (true) {
		fd_set fds;

		FD_ZERO(&fds);
		FD_SET(STDIN_FILENO, &fds);
		FD_SET(fsck_fd, &fds);

		select(fsck_fd + 1, &fds, NULL, NULL, NULL);

		int r = do_splice(fsck_fd, STDOUT_FILENO) ?:
			do_splice(STDIN_FILENO, fsck_fd);
		if (r)
			return r < 0 ? r : 0;
	}

	pr_info("done");
	return 0;
}

int cmd_fsck(int argc, char *argv[])
{
	static const struct option longopts[] = {
		{ "ratelimit_errors",	no_argument,		NULL, 'r' },
		{ "reconstruct_alloc",	no_argument,		NULL, 'R' },
		{ "help",		no_argument,		NULL, 'h' },
		{ NULL }
	};
	struct bch_opts opts = bch2_opts_empty();
	int opt, ret = 0;

	opt_set(opts, degraded, true);
	opt_set(opts, fsck, true);
	opt_set(opts, fix_errors, FSCK_FIX_ask);

	while ((opt = getopt_long(argc, argv,
				  "apynfo:rvh",
				  longopts, NULL)) != -1)
		switch (opt) {
		case 'a': /* outdated alias for -p */
		case 'p':
		case 'y':
			opt_set(opts, fix_errors, FSCK_FIX_yes);
			break;
		case 'n':
			opt_set(opts, nochanges, true);
			opt_set(opts, fix_errors, FSCK_FIX_no);
			break;
		case 'f':
			/* force check, even if filesystem marked clean: */
			break;
		case 'o':
			ret = bch2_parse_mount_opts(NULL, &opts, optarg);
			if (ret)
				return ret;
			break;
		case 'r':
			opt_set(opts, ratelimit_errors, true);
			break;
		case 'R':
			opt_set(opts, reconstruct_alloc, true);
			break;
		case 'v':
			opt_set(opts, verbose, true);
			break;
		case 'h':
			usage();
			exit(16);
		}
	args_shift(optind);

	if (!argc) {
		fprintf(stderr, "Please supply device(s) to check\n");
		exit(8);
	}

	darray_str devs = get_or_split_cmdline_devs(argc, argv);

	darray_for_each(devs, i)
		if (dev_mounted(*i))
			return fsck_online(*i);

	struct bch_fs *c = bch2_fs_open(devs.data, devs.nr, opts);
	if (IS_ERR(c))
		exit(8);

	if (test_bit(BCH_FS_errors_fixed, &c->flags)) {
		fprintf(stderr, "%s: errors fixed\n", c->name);
		ret |= 1;
	}
	if (test_bit(BCH_FS_error, &c->flags)) {
		fprintf(stderr, "%s: still has errors\n", c->name);
		ret |= 4;
	}

	bch2_fs_stop(c);
	return ret;
}
