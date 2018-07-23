# dotfiles #

my dotfile and text editor configurations

## Getting Started

Fork this repo before running bootstrap or dotfiles install.

## Deployment

### Automatic Installation

_substitute github username where appropriate_
```bash
# 1. read script carefully
curl https://raw.githubusercontent.com/${github_user}/dotfiles/master/bin/bin/bootstrap

# 2. run script
curl https://raw.githubusercontent.com/${github_user}/dotfiles/master/bin/bin/bootstrap | bash -s klutchell
```

### Manual Installation

_substitute github username where appropriate_
```bash
# 1. install utilities
sudo apt-get install -y make git stow curl

# 2. generate key (follow prompts)
ssh-keygen

# 3. import ssh key to github account
curl --user "${github_user}" --data "{\"title\":\"$(echo $(<~/.ssh/id_rsa.pub) | cut -d' ' -f3-)\",\"key\":\"$(<~/.ssh/id_rsa.pub)\"}" https://api.github.com/user/keys

# 4. export ssh keys from github account
curl https://github.com/${github_user}.keys >> ~/.ssh/authorized_keys

# 5. clone
git clone git@github.com:${github_user}/dotfiles.git ~/.dotfiles

# 6. install
cd ~/.dotfiles && make install
```

## Author

Kyle Harding <kylemharding@gmail.com>

## License

_tbd_

## Acknowledgments

_tbd_
