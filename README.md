# dotfiles #

my dotfile and text editor configurations

## Getting Started

Fork this repo before running bootstrap or dotfiles install.

## Deployment

In order to clone your dotfiles repo via SSH on a new workstation,
you'll need an SSH key added to your github account.

### Add SSH key to Github automatically

You can use this utility from command line to generate a new rsa-ssh key,
and add it to your Github account if you don't already have one.
_You will be prompted for your github username and password._
```bash
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/githubkeygen | bash
```

### Add SSH key to Github manually

Follow these steps to generate a new rsa-key and add it to your Github account.
```bash
ssh-keygen -t "rsa" -b "4096"
```
Next steps: https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

### Install dotfiles automatically

Once your workstation is authenticated with Github,
run this script to clone and install your dotfiles.
_You will be prompted for your github username and rsa-key path._
```bash
curl https://raw.githubusercontent.com/klutchell/dotfiles/master/bin/bin/bootstrap | bash
```

### Install dotfiles manually

Once your workstation is authenticated with Github,
run these commands to clone and install your dotfiles.
```bash
sudo apt-get install -y make git stow
git clone git@github.com:<github_username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
make install
```

## Author

Kyle Harding <kylemharding@gmail.com>

## License

_tbd_

## Acknowledgments

_tbd_
