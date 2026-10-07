"""qBittorrent's WebUI password format, so its login can be set from Proton Pass (its image has no
openssl/python to do this on the host)."""
import base64
import hashlib


def qbt_password_hash(password):
    """PBKDF2-HMAC-SHA512, 100000 rounds, 16-byte salt, as qBittorrent stores it (WebUI\\Password_PBKDF2).

    ponytail: the salt comes from the password itself, so the same password gives the same hash and
    Ansible stays idempotent. Two accounts sharing a password would share a hash; there is one account.
    """
    salt = hashlib.sha256(b"qbittorrent-webui:" + password.encode()).digest()[:16]
    key = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100000, 64)
    return "@ByteArray(%s:%s)" % (base64.b64encode(salt).decode(), base64.b64encode(key).decode())


class FilterModule:
    def filters(self):
        return {"qbt_password_hash": qbt_password_hash}


if __name__ == "__main__":
    h = qbt_password_hash("hunter2")
    assert h == qbt_password_hash("hunter2") and h != qbt_password_hash("hunter3")
    salt, key = h[len("@ByteArray("):-1].split(":")
    assert len(base64.b64decode(salt)) == 16 and len(base64.b64decode(key)) == 64
    print("ok", h)
