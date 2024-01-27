echo "This script will install oh-my-zsh and several plugins. Continue? (y/n)"
read answer
if echo "$answer" | grep -iq "^y" ;then

if ! which zsh > /dev/null; then
    echo "zsh not found. Installing..."
    if [ "$(uname)" == "Darwin" ]; then
        # macOS-specific commands here
        echo "Detected macOS. Installing zsh..."
        brew install zsh
    elif [ -f /etc/arch-release ]; then
        # Arch Linux-specific commands here
        echo "Detected Arch Linux. Installing zsh..."
        sudo pacman -S zsh
    elif [ -f /etc/debian_version ]; then
        # Debian/Ubuntu-specific commands here
        echo "Detected Debian/Ubuntu. Installing zsh..."
        sudo apt install zsh
    else
        echo "Unsupported operating system. Please install zsh manually."
        exit 1
    fi
fi
    # install oh-my-zsh plugins
    # ------------------------------------------------------------------------------
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended | yes

    source ~/.zshrc
    # ------------------------------------------------------------------------------
    #install zsh-autosuggestions and auto completion plugins    
    # ------------------------------------------------------------------------------
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions

    # ------------------------------------------------------------------------------
    #install zsh-syntax-highlighting
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

    # ------------------------------------------------------------------------------
    #install fast-syntax-highlighting
    echo "Installing fast-syntax-highlighting..."
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting

    # ------------------------------------------------------------------------------
    # install zsh-autocomplete
    echo "Installing zsh-autocomplete..."
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git $ZSH_CUSTOM/plugins/zsh-autocomplete

    if [ "$(uname)" == "Darwin" ]; then
        # macOS-specific commands here
        echo "Detected macOS. Updating .zshrc..."
        sed -i '' -E "s/plugins=\((.*)\)/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/" ~/.zshrc
    else
        # Other OS-specific commands here
        echo "Detected Linux. Updating .zshrc..."
        sed -i -E "s/plugins=\((.*)\)/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/" ~/.zshrc
    fi
else
    echo "Installation cancelled."
fi