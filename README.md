# Homebrew tap for Vois Studio

Vois Studio makes voiceovers, podcasts and audiobooks on your computer. This tap installs Vois Studio on an Apple Silicon Mac with one Homebrew command.

## Install Vois Studio

```bash
brew install --cask vois-so/tap/vois-studio
```

You must have:

- A Mac with Apple Silicon (M1 or newer).
- macOS 12 or newer.
- [Homebrew](https://brew.sh).

When you use the full name `vois-so/tap/vois-studio`, Homebrew adds this tap and trusts the cask. Then open Vois Studio in the `/Applications` folder.

## Update Vois Studio

Vois Studio updates itself. When a new version is available, the app tells you.

To update Vois Studio with Homebrew, use this command:

```bash
brew upgrade --cask vois-studio
```

## Remove Vois Studio

To remove the app and keep your projects, voices and other data, use this command:

```bash
brew uninstall --cask vois-studio
```

To remove the app and all of its data, use this command:

```bash
brew uninstall --cask --zap vois-studio
```

> [!WARNING]
> With `--zap`, Homebrew moves your projects, your voices, the voice engines that you downloaded, your license file and all other app data to the Trash. Make a backup in Vois Studio before you use it.

## Windows

For Windows, [download Vois Studio](https://vois.so/download?utm_source=github&utm_medium=homebrew-tap&utm_campaign=oss). To install Vois Studio with winget in the future, add a thumbs-up reaction to [issue 5](https://github.com/vois-so/vois-studio/issues/5).

## Tell us about a problem

This repository has only the Homebrew cask. To tell us about a problem with the cask or with the app, open an issue in [vois-studio](https://github.com/vois-so/vois-studio/issues/new/choose).

## Update the cask

This part is for the Vois Studio team. After we release a new version, use this command:

```bash
scripts/bump-cask.sh
```

The script gets the version from the production update manifest. To use a different version, add the version to the command, for example `scripts/bump-cask.sh 2.6.3`.

The script downloads the DMG and calculates its SHA-256. Before it changes the cask, it examines these items of Vois.app in the DMG:

- The bundle identifier.
- The version.
- The code signature.
- The Developer ID team.
- The notarization.

The script does not commit or push.

For each change to this repository, the `checks` workflow does these steps:

1. It does the `brew style` and `brew audit` checks.
2. It installs the cask on a macOS runner and examines the app.
3. It removes the cask.

## License

The files in this repository have the [MIT license](LICENSE). The Vois Studio app has its own [terms](https://vois.so/legal/terms). The Free plan has no time limit. It is for personal and non-commercial use.
