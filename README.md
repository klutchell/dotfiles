# dotfiles #

## Description

my dotfile and text editor configurations

## Bootstrap
```bash
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/bootstrap | bash
```

## Install Utilities Only
```bash
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/install | sudo bash -s <utilities>
```

## Install Dotfiles Only
```bash
sudo apt install -y make stash
git clone git@github.com:klutchell/dotfiles.git ~/dotfiles
cd ~/dotfiles
make install
```

## Author

Kyle Harding <kylemharding@gmail.com>
