# dotfiles #

## Description

my dotfile and text editor configurations

## Usage

Fork this repo before running bootstrap or dotfiles install.

### Bootstrap a new workstation
```bash
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/bootstrap | bash
```

### Install dotfiles manually
```bash
sudo apt install -y make git stow
git clone git@github.com:klutchell/dotfiles.git ~/dotfiles
cd ~/dotfiles
make install
```

## Author

Kyle Harding <kylemharding@gmail.com>
