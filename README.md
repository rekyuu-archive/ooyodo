# Ooyodo Telegram Bot

A bot wrapper for [Nadia](https://github.com/zhyu/nadia).

## Quick Start

To get started, [download the latest release](https://github.com/rekyuu/ooyodo/releases) and install the archive with mix:

```
$ mix archive.install Ooyodo.New.ez
```

Then create a new project:

```
$ mix ooyodo.new appname --token your_api_token
```

Then to run:

```
$ cd appname
$ mix deps.get
$ mix appname
```

## Development

Tested update types:

[x] Messages
[x] Inline queries
[x] Edited messages
[ ] Chosen inline results
[ ] Callback queries
