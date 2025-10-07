# mpv-jumpto
**Jump to** plugin for mpv

![Example for Jumpto](https://github.com/magnum357i/mpv-jumpto/blob/main/jumpto.jpg)

*Inspired by default mpv panels*

# Usage

https://github.com/user-attachments/assets/a1be69e1-e676-42fa-90e0-c63cd9a544cb

# Key Bindings
| shortcut            | description                  |
| ------------------- | ---------------------------- |
| <kbd>Ctrl+j</kbd>   | open jump panel by frame     |
| <kbd>Ctrl+J</kbd>   | open jump panel by timestamp |

# Commands
Add these lines to input.conf to step through frames while showing their numbers.

```
Ctrl+Left script-binding jumpto_prevframe
Ctrl+Right script-binding jumpto_nextframe
```