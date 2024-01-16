#include "libbcachefs/super-io.h"
#include "libbcachefs/checksum.h"
#include "libbcachefs/bcachefs_format.h"
#include "libbcachefs/btree_cache.h"
#include "libbcachefs/btree_iter.h"
#include "libbcachefs/debug.h"
#include "libbcachefs/errcode.h"
#include "libbcachefs/error.h"
#include "libbcachefs/opts.h"
#include "libbcachefs.h"
#include "crypto.h"
#include "include/linux/bio.h"
#include "include/linux/blkdev.h"
#include "cmds.h"
#include "raid/raid.h"


#define MARK_FIX_753(req_name) const blk_mode_t Fix753_##req_name = req_name;

MARK_FIX_753(BLK_OPEN_READ);
MARK_FIX_753(BLK_OPEN_WRITE);
MARK_FIX_753(BLK_OPEN_EXCL);
