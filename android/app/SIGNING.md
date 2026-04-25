# Android Upload Key — `upload-keystore.jks`

The `flutter-aab-final` workflow signs the Play Store AAB with a Java
KeyStore committed to **`android/app/upload-keystore.jks`**. The
keystore itself is binary and **must be committed to the repo by you**
— it can't be reconstructed from the SHA fingerprints below; those are
one-way hashes derived from the key.

## Fingerprints

The keystore currently in the repo (`upload-keystore.jks`) produces:

```
SHA-1   : 1B:12:A2:B6:52:EF:95:20:BE:B9:8D:60:07:73:78:23:3F:2D:45:43
SHA-256 : EF:50:14:19:F0:EC:BD:B0:BB:33:B9:E1:44:02:FF:5C:A4:FA:38:02:FD:5A:0F:67:DF:73:50:E5:2B:32:68:AF
```

The fingerprints originally registered with Play Console were:

```
SHA-1   : C2:27:D7:BE:A2:38:70:40:16:6A:E3:D9:BD:23:39:8D:60:DC:08:DE
SHA-256 : 76:E1:49:7A:35:36:DD:9A:02:8C:DB:46:5F:F8:D2:38:18:C0:FC:40:A2:55:53:C5:C7:AB:CF:2B:A7:5C:BD:ED
```

If those two sets don't match, the AAB this repo builds **will be
rejected** at Play Console upload — Play matches the upload key to
the registered fingerprints. Two ways to fix:

1. Replace `upload-keystore.jks` with the original keystore that
   produced the registered fingerprints (then the SHAs above will
   re-match).
2. Or reset the upload key in Play Console → *Setup → App integrity
   → Reset upload key* and submit the SHA-256 from this keystore.
   Google approves instantly; after that, AABs built here upload fine.

The workflow's `Verify keystore` step prints the live SHA-1 to the
build log so you can eyeball-confirm which keystore is currently in
the repo.

## Keystore creds (must match `flutter-aab-final.yml`)

```
keystore  : android/app/upload-keystore.jks
alias     : skeletalpt
storepass : skeletalpt123
keypass   : skeletalpt123
```

`build.gradle.kts` reads these from env vars (set by the workflow)
with a hardcoded fallback to the same values, so a local
`flutter build appbundle --release` Just Works once the .jks is in
place.

## How to drop in the keystore

1. Find your existing `upload-keystore.jks` (the one whose fingerprints
   are registered with Play Console — values above).
2. Copy it to `android/app/upload-keystore.jks` in this repo.
3. `git add android/app/upload-keystore.jks && git commit -m "Add upload keystore"`
4. Push. The workflow will pick it up on the next run.

## If you've lost the keystore

If you opted into Play App Signing, Google holds the **app signing
key** for you and you only need a fresh **upload key** — generate a
new one and upload the new SHA-256 to Play Console under
*Setup → App integrity → Upload key certificate → Reset upload key*.

Generate command:

```sh
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias skeletalpt \
  -storepass skeletalpt123 -keypass skeletalpt123 \
  -dname "CN=Mirrorly,O=Mirrorly,C=GB"
```

Then read the new SHA-256:

```sh
keytool -list -v \
  -keystore android/app/upload-keystore.jks \
  -alias skeletalpt -storepass skeletalpt123 \
  | grep "SHA256:"
```

Submit that to Play Console and update the value at the top of this
file.

## Security note

Committing a real keystore + creds to the repo is a security trade-off
the team has explicitly chosen here (workflow YAML already pastes the
creds in plaintext). If this repo ever goes public, **rotate this key
and use Play Console's "Reset upload key" flow** before publishing.
