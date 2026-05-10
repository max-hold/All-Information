## Termianl Base App Build 
- TUI terminal / ncurses

- whiptail
  This is the closest drop-in replacement. It lightweight (popular in installers). It has a similar but sometimes cleaner look.
  Install: `apk add newt`

- gum / charm.land
  This is the most "modern" TUI option. It offers stylish, customizable components with great colors, animations. It's excellent for writing interactive shell scripts.
  Install: `apk add gum`

## GUI Alternatives (actual graphical dialogs — "more modern UI")

- zenity: Displays GTK dialog boxes (info, question, file picker, forms, etc.) from shell scripts. Very straightforward.
  Install: `apk add zenity`

- yad (Yet Another Dialog): An enhanced, actively maintained fork of zenity with more features and flexibility.
  Install: `apk add yad`

