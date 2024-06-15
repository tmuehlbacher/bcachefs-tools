use std::{
    ffi::{c_long, CStr, CString},
    fs,
    io::{stdin, IsTerminal},
    mem,
    path::Path,
    ptr, thread,
    time::Duration,
};

use anyhow::{anyhow, ensure, Result};
use bch_bindgen::{
    bcachefs::{self, bch_key, bch_sb_handle},
    c::{bch2_chacha_encrypt_key, bch_sb_field_crypt},
    keyutils::{self, keyctl_search},
};
use byteorder::{LittleEndian, ReadBytesExt};
use log::info;
use uuid::Uuid;
use zeroize::{ZeroizeOnDrop, Zeroizing};

use crate::{c_str, ErrnoError};

const BCH_KEY_MAGIC: &str = "bch**key";

#[derive(Clone, Debug, clap::ValueEnum, strum::Display)]
pub enum UnlockPolicy {
    Fail,
    Wait,
    Ask,
}

impl UnlockPolicy {
    pub fn apply(&self, sb: &bch_sb_handle) -> Result<KeyHandle> {
        let uuid = sb.sb().uuid();

        info!("Using filesystem unlock policy '{self}' on {uuid}");

        match self {
            Self::Fail => Err(anyhow!("no passphrase available")),
            Self::Wait => Ok(KeyHandle::wait_for_unlock(&uuid)?),
            Self::Ask => Passphrase::new_from_prompt().and_then(|p| KeyHandle::new(sb, &p)),
        }
    }
}

impl Default for UnlockPolicy {
    fn default() -> Self {
        Self::Ask
    }
}

/// A handle to an existing bcachefs key in the kernel keyring
pub struct KeyHandle {
    // FIXME: Either these come in useful for something or we remove them
    _uuid: Uuid,
    _id:   c_long,
}

impl KeyHandle {
    pub fn format_key_name(uuid: &Uuid) -> CString {
        CString::new(format!("bcachefs:{uuid}")).unwrap()
    }

    pub fn new(sb: &bch_sb_handle, passphrase: &Passphrase) -> Result<Self> {
        let bch_key_magic = BCH_KEY_MAGIC.as_bytes().read_u64::<LittleEndian>().unwrap();

        let crypt = sb.sb().crypt().unwrap();
        let crypt_ptr = (crypt as *const bch_sb_field_crypt).cast_mut();

        let mut output: bch_key =
            unsafe { bcachefs::derive_passphrase(crypt_ptr, passphrase.get().as_ptr()) };

        let mut key = *crypt.key();

        let ret = unsafe {
            bch2_chacha_encrypt_key(
                ptr::addr_of_mut!(output),
                sb.sb().nonce(),
                ptr::addr_of_mut!(key).cast(),
                mem::size_of_val(&key),
            )
        };

        ensure!(ret == 0, "chacha decryption failure");
        ensure!(key.magic == bch_key_magic, "failed to verify passphrase");

        let key_name = Self::format_key_name(&sb.sb().uuid());
        let key_name = CStr::as_ptr(&key_name);
        let key_type = c_str!("user");

        let key_id = unsafe {
            keyutils::add_key(
                key_type,
                key_name,
                ptr::addr_of!(output).cast(),
                mem::size_of_val(&output),
                keyutils::KEY_SPEC_USER_KEYRING,
            )
        };

        if key_id > 0 {
            info!("Found key in keyring");
            Ok(KeyHandle {
                _uuid: sb.sb().uuid(),
                _id:   c_long::from(key_id),
            })
        } else {
            Err(anyhow!("failed to add key to keyring: {}", errno::errno()))
        }
    }

    pub fn new_from_search(uuid: &Uuid) -> Result<Self> {
        let key_name = Self::format_key_name(uuid);
        let key_name = CStr::as_ptr(&key_name);
        let key_type = c_str!("user");

        let key_id =
            unsafe { keyctl_search(keyutils::KEY_SPEC_USER_KEYRING, key_type, key_name, 0) };

        if key_id > 0 {
            info!("Found key in keyring");
            Ok(Self {
                _uuid: *uuid,
                _id:   key_id,
            })
        } else {
            Err(ErrnoError(errno::errno()).into())
        }
    }

    fn wait_for_unlock(uuid: &Uuid) -> Result<Self> {
        loop {
            match Self::new_from_search(uuid) {
                Err(_) => thread::sleep(Duration::from_secs(1)),
                r => break r,
            }
        }
    }
}

#[derive(ZeroizeOnDrop)]
pub struct Passphrase(CString);

impl Passphrase {
    fn get(&self) -> &CStr {
        &self.0
    }

    // blocks indefinitely if no input is available on stdin
    fn new_from_prompt() -> Result<Self> {
        let passphrase = if stdin().is_terminal() {
            Zeroizing::new(rpassword::prompt_password("Enter passphrase: ")?)
        } else {
            info!("Trying to read passphrase from stdin...");
            let mut line = Zeroizing::new(String::new());
            stdin().read_line(&mut line)?;
            line
        };

        Ok(Self(CString::new(passphrase.trim_end_matches('\n'))?))
    }

    pub fn new_from_file(sb: &bch_sb_handle, passphrase_file: impl AsRef<Path>) -> Result<Self> {
        let passphrase_file = passphrase_file.as_ref();

        info!(
            "Attempting to unlock key for filesystem {} with passphrase from file {}",
            sb.sb().uuid(),
            passphrase_file.display()
        );

        let passphrase = Zeroizing::new(fs::read_to_string(passphrase_file)?);

        Ok(Self(CString::new(passphrase.trim_end_matches('\n'))?))
    }
}
