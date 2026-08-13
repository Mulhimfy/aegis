# Hosting for aegis.app

Two files and a landing page. Everything else in the product runs on the phone.

```
.well-known/assetlinks.json               Android verified links
.well-known/apple-app-site-association    iOS universal links
```

Both must be served over HTTPS, from the apex `aegis.app`, with no redirect and
`Content-Type: application/json`. The Apple file has no extension: that is not
a mistake, it is what Apple requires.

## Before they work

1. `assetlinks.json`: replace the fingerprint with the SHA-256 of the signing
   key Play actually uses. Take it from Play Console under
   Release > Setup > App signing, not from your upload keystore, because Play
   re-signs the app.
2. `apple-app-site-association`: replace `REPLACE_WITH_TEAMID` with the Apple
   Developer Team ID, and add the Associated Domains capability
   (`applinks:aegis.app`) to the Runner target.

Until then the `aegis://` custom scheme still carries every invite, so the loop
works. Verified links only remove the "open with" chooser.

## The landing page

`/s/<code>` and `/c/<code>` should render a page that sends people to the store
listing for their platform, and repeats the number from the `v` parameter when
there is one. Someone arriving on a desktop is the most common way an invite
gets lost, and that page is the only thing standing in the way.
