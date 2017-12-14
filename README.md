# dotfiles #

my dotfile and text editor configurations

## Getting Started

Fork this repo before running bootstrap or dotfiles install.

## Deployment

### Automatic Installation

_substitute github username where appropriate_
```bash
# 1. read script carefully
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/bootstrap

# 2. run script
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/bootstrap | bash -s klutchell
```

### Manual Installation

_substitute github username where appropriate_
```bash
# 1. install handy utilities
sudo apt-get install -y make git stow ntp shellcheck

# 2. generate an rsa key
ssh-keygen -t "rsa" -b "4096"

# 3. add rsa key to github account
# https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

# 4. clone dotfiles repo
git clone git@github.com:klutchell/dotfiles.git ~/.dotfiles

# 5. install dotfiles
cd ~/.dotfiles && make install
```

## Author

Kyle Harding <kylemharding@gmail.com>

## License

_tbd_

## Acknowledgments

_tbd_
