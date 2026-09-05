# MPV

My mpv setup: player settings, a keybind map I keep expanding, a [uosc][UOSC] theme, and the script selection I actually use.

<p align="center">
  <img alt="mpv" src="https://github.com/user-attachments/assets/8a902a84-a526-49f9-b456-066a2b727981" width="49%"/>
  &nbsp;&nbsp;
  <img alt="mpv_context_menu" src="https://github.com/user-attachments/assets/6f6654ac-246c-4f0b-8603-ab4e4993b7e9" width="49%"/>
</p>

> [!NOTE]
> Two things are deliberately missing: the **shaders**, too large to commit, and the **[uosc][UOSC] folder**, which I keep unmodified from upstream.

## Install

Copy `portable_config/` next to `mpv.exe`. Two folders you supply.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"darkMode": true, "background": "#0d0e17", "textColor": "#f8eaf8", "treeView": {"labelColor": "#f8eaf8", "lineColor": "#30363d", "iconColor": "#8b949e"}}}}%%
treeView-beta
portable_config/
    mpv.conf
    input.conf
    profiles.conf
    fonts.conf
    fonts/
    script-opts/
        uosc.conf ## the theme
    scripts/
        uosc/ ## add from upstream
    shaders/ ## add your own
```

## Scripts I wrote

Both use the Moonlight palette below.

<p align="center">
  <img alt="keybind-visualizer and sub-seek" src="assets/keybind-visualizer-and-sub-seek.gif" width="100%"/>
</p>

### [`keybind-visualizer.lua`][keybind_visualizer]

An on-screen keyboard on `F6`. Hover a key to see what it does; `ESC` closes it.

Bindings are read live from `input-bindings`, so it reflects your `input.conf` plus the builtins, with no list to maintain.

mpv cannot detect the OS keyboard layout, so layouts live in a JSON file. Pick `ansi`, `iso`, `abnt2`, `jis`, or add your own.

| File                                                            | Purpose                                                   |
| --------------------------------------------------------------- | --------------------------------------------------------- |
| [`keybind-visualizer.conf`][keybind_visualizer_conf]            | Selects the `layout` and points at the layouts file       |
| [`keybind-visualizer-layouts.json`][keybind_visualizer_layouts] | The layout definitions; edit to move keys or add a layout |

### [`sub-seek.lua`][sub_seek]

A fullscreen, clickable index of every subtitle line with timestamps, on `F4`. Click a line, or arrow to it and press Enter, to seek there. Like the builtin sub-seek, except you jump anywhere instead of stepping.

mpv exposes no "all subtitle lines" API, so the track is dumped to a temporary `.srt` with ffmpeg and parsed; ASS and embedded subs get flattened on the way.

## The uosc theme

Moonlight: dark, low-contrast, chrome kept thin. Set in [`uosc.conf`][uosc_conf].

| Role              | Hex       | Used for                       |
| ----------------- | --------- | ------------------------------ |
| `foreground`      | `#ced9ff` | Timeline fill, active controls |
| `foreground_text` | `#0d0e17` | Text on top of that fill       |
| `background`      | `#191726` | Menus, tooltips, bars          |
| `background_text` | `#f8eaf8` | Text on those surfaces         |
| `curtain`         | `#0d0e17` | Dim behind open menus          |
| `success`         | `#49ef95` | Positive feedback              |
| `error`           | `#ca5f71` | Failures                       |

Shape matters as much: `timeline_style=bar` at 20px, `top_bar=no-border`, `border_radius=2`, `font_scale=1.18`, `font_bold=yes`. Most surfaces sit under full opacity; the title is transparent, so nothing floats over the video.

## Configuration

| File                            | What it holds                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------- |
| [`mpv.conf`][mpv_conf]          | Preferred languages, OSC and window behaviour, subtitle styling, video output and tone mapping |
| [`input.conf`][input_conf]      | Every keybind, plus the uosc menu                                                              |
| [`profiles.conf`][profile_conf] | Conditional profiles                                                                           |
| [`fonts.conf`][fonts_conf]      | Legacy; loaded Windows fonts before `fonts/` replaced it                                       |

<p align="center">
  <img alt="input_conf_1" src="https://github.com/user-attachments/assets/48b1bea8-c424-41ef-915d-a61575affdac" width="49%"/>
  <img alt="input_conf_2" src="https://github.com/user-attachments/assets/d426835c-f2d8-450a-8a78-7580ca77bc85" width="49%"/>
</p>

`input.conf` is the piece I put the most into: every binding mpv accepts written out as a comment, grouped by keyboard row, with mine active among them, then the shader keys and the uosc menu. Of all the ones I read for inspiration, none were this complete.

`profiles.conf` swaps the shader chain and subtitle styling when the path contains `Animation`, plus profiles for audio-only files and upscaling.

## Script selection

Most fire off playback itself, no keypress needed.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"darkMode": true, "background": "#0d0e17", "mainBkg": "#191726", "primaryColor": "#191726", "primaryTextColor": "#f8eaf8", "primaryBorderColor": "#7386d0", "secondaryColor": "#282e46", "secondaryTextColor": "#f8eaf8", "secondaryBorderColor": "#5dabf3", "tertiaryColor": "#3c466f", "tertiaryTextColor": "#f8eaf8", "tertiaryBorderColor": "#79c0ff", "lineColor": "#7386d0", "textColor": "#f8eaf8", "titleColor": "#f8eaf8", "nodeBorder": "#7386d0", "nodeTextColor": "#f8eaf8", "clusterBkg": "#12131f", "clusterBorder": "#30363d", "edgeLabelBackground": "#191726", "arrowheadColor": "#7386d0", "border1": "#7386d0", "border2": "#8b949e", "errorBkgColor": "#3c466f", "errorTextColor": "#f8eaf8", "fontFamily": "Mulish, system-ui, sans-serif", "fontSize": "14px"}}}%%
flowchart TB
  subgraph opens["When a file opens"]
    direction TB
    p["profiles.conf picks a profile"] --> s["sub-select picks tracks"] --> a["autoload queues the folder"]
  end
  subgraph plays["While it plays"]
    direction TB
    t["thumbfast seekbar previews"] --> k["F6 keybinds, F4 sub index"]
  end
  subgraph ends["As it ends"]
    direction TB
    n["anilistUpdater at 85%"] --> w["watched-folder on finish"]
  end
  opens --> plays --> ends
```

| Script                                   | Source                            | What it does                                            |
| ---------------------------------------- | --------------------------------- | ------------------------------------------------------- |
| [`anilistUpdater`][anilist]              | [AzuredBlue][anilist_src]         | Marks the episode watched on AniList at 85%             |
| [`autoload.lua`][autoload]               | [mpv][autoload_src]               | Queues the neighbouring files in the folder             |
| [`chapters.lua`][chapters]               | [mar04][chapters_src]             | Create, edit and save chapters                          |
| [`clipshot.lua`][clipshot]               | [ObserverOfTime][clipshot_src]    | Screenshot straight to the clipboard                    |
| [`pause-indicator.lua`][pause_indicator] | [CogentRedTester][crt]            | Pause glyph in the corner                               |
| [`reactive_vf_bypass.lua`][vf_bypass]    | [allecsc][allecsc]                | Keeps the SVP filter chain honest                       |
| [`restart-mpv.lua`][restart_mpv]         | mine                              | Reloads the file so config edits apply                  |
| `skip-chapters.lua`                      | unattributed                      | Auto-skips chapters matching OP, ED, credits or preview |
| [`skip-to-silence.lua`][skip_silence]    | [detuur][detuur]                  | Jumps to the next silence, usually the OP's end         |
| [`sub-export.lua`][sub_export]           | [kelciour][kelciour]              | Extracts the current subtitle next to the video         |
| [`sub-select.lua`][sub_select]           | [CogentRedTester][sub_select_src] | Picks audio and subtitle tracks by rules                |
| [`thumbfast.lua`][thumbfast]             | [po5][thumbfast_src]              | Seekbar hover thumbnails                                |
| [`watched-folder.lua`][watched_folder]   | mine                              | Moves a finished file to a "watched" folder             |

Several carry local patches, `thumbfast.lua` most of all.

`watched-folder.lua` has two known bugs: it fires when you switch files without finishing, and it skips the last file in a playlist.

<details>

<summary>Scripts kept but not loaded</summary>

Tried and dropped, kept for reference: `autodeint.lua`, `better-chapter.lua`, `inputevent.lua`, `memo.lua`, `mute-on-specific-subtitle-words.js`, `osc.lua`, `pause-indicator-middle.lua`, `sub-bilingual.lua`.

</details>

## Shaders and fonts

Shaders, [Anime4K][Anime4k] among them, are too large to commit; [`shaders_list.txt`][shaders_list] names them all. Fonts sit in `fonts/` because the Windows font folder loads slower.

<!-- URLS -->

[keybind_visualizer]: ./portable_config/scripts/keybind-visualizer.lua
[keybind_visualizer_conf]: ./portable_config/script-opts/keybind-visualizer.conf
[keybind_visualizer_layouts]: ./portable_config/script-opts/keybind-visualizer-layouts.json
[sub_seek]: ./portable_config/scripts/sub-seek.lua
[Anime4k]: https://github.com/bloc97/Anime4K
[UOSC]: https://github.com/tomasklaen/uosc
[mpv_conf]: ./portable_config/mpv.conf
[input_conf]: ./portable_config/input.conf
[profile_conf]: ./portable_config/profiles.conf
[fonts_conf]: ./portable_config/fonts.conf
[uosc_conf]: ./portable_config/script-opts/uosc.conf
[shaders_list]: ./portable_config/shaders/shaders_list.txt
[anilist]: ./portable_config/scripts/anilistUpdater
[anilist_src]: https://github.com/AzuredBlue/mpv-anilist-updater
[autoload]: ./portable_config/scripts/autoload.lua
[autoload_src]: https://github.com/mpv-player/mpv
[chapters]: ./portable_config/scripts/chapters.lua
[chapters_src]: https://github.com/mar04/chapters_for_mpv
[clipshot]: ./portable_config/scripts/clipshot.lua
[clipshot_src]: https://github.com/ObserverOfTime/mpv-scripts
[pause_indicator]: ./portable_config/scripts/pause-indicator.lua
[crt]: https://github.com/CogentRedTester/mpv-scripts
[vf_bypass]: ./portable_config/scripts/reactive_vf_bypass.lua
[allecsc]: https://github.com/allecsc/mpv-qol-scripts
[restart_mpv]: ./portable_config/scripts/restart-mpv.lua
[skip_silence]: ./portable_config/scripts/skip-to-silence.lua
[detuur]: https://github.com/detuur/mpv-scripts
[sub_export]: ./portable_config/scripts/sub-export.lua
[kelciour]: https://github.com/kelciour/mpv-scripts
[sub_select]: ./portable_config/scripts/sub-select.lua
[sub_select_src]: https://github.com/CogentRedTester/mpv-sub-select
[thumbfast]: ./portable_config/scripts/thumbfast.lua
[thumbfast_src]: https://github.com/po5/thumbfast
[watched_folder]: ./portable_config/scripts/watched-folder.lua
