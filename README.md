# mpv-jumpto
**Jump to** plugin for mpv

![Example for Jumpto](https://github.com/magnum357i/mpv-jumpto/blob/main/jumpto.jpg)
![Example for Jumpto 2](https://github.com/magnum357i/mpv-jumpto/blob/main/jumpto2.jpg)
*Inspired by default mpv panels*

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