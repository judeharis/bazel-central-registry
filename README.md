# Bazel Central Registry

## Overview

The default Bazel registry for the Bzlmod external dependency system of Bazel. It is the recommended place to find and publish your favorite Bazel projects. Visit https://registry.bazel.build to check what modules are already available!

## Contributing

To contribute, check our [BCR  policies](docs/bcr-policies.md) and [contribution guidelines](docs/README.md).

## Depending on the BCR infrastructure (and how not to)

The core infrastructure of the Bazel Central Registry depends on GitHub and Google Cloud. Bazel users who enable Bzlmod depend on the BCR by default.
While we try to keep the BCR infrastructure simple and reliable, we assume no liability for any damages caused by build failures due to potential BCR infrastructure failures.

If you consider it necessary, you can do the following to avoid depending on the BCR infrastructure while still making use of the information checked into the BCR.

- Clone the BCR repository or mirror the content to your own infrastructure and use the [--registry](https://bazel.build/reference/command-line-reference#flag--registry) option to change the default Bazel registry to your own.
- Host your own mirror for all source archive URLs and add the mirror URL in `./bazel_registry.json`.
  You can run `bazel run //tools:print_all_src_urls` to get the list of source URLs to mirror for all Bazel modules checked into the BCR.
  For example, `https://foo.com/bar.zip` should be mirrored to `https://<your mirror>/foo.com/bar.zip`.

## How to update a module

- Add a new version to the module's `metadata.json` file.
- Upload the new version as a github release.
- Create a version folder in the module's directory, with new link to the release.
- Get the sha256 hash of the new version.

Use the following to gen hash:
```
openssl dgst -sha256 -binary secda_tools-0.1.0.tar.gz | openssl base64 -A
openssl dgst -sha256 -binary secda_tools-0.2.0.tar.gz | openssl base64 -A
openssl dgst -sha256 -binary secda_tools-0.2.0b.tar.gz | openssl base64 -A
openssl dgst -sha256 -binary secda_tools-0.2.0d.tar.gz | openssl base64 -A
openssl dgst -sha256 -binary secda_tools-0.2.1.tar.gz | openssl base64 -A


openssl dgst -sha256 -binary add_build_file.patch | openssl base64 -A

```

