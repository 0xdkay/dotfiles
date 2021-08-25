if OS.mac?
  # macOS
  brew "reattach-to-user-namespace"

  # Basic tools
  brew "cmake"
  brew "cscope"
  brew "ctags"
  brew "git"
  brew "openssh"
  brew "tmux"
  brew "wget"
  brew "zsh"

  # QLColorCode
  brew "highlight" if MacOS.version < :catalina
end

# Utilities
brew "clementtsang/bottom/bottom"
brew "keychain" if OS.mac?
brew "pre-commit"
brew "z"

# Don't have bottles for Rust
unless OS.mac? && MacOS.version < :mojave
  brew "bat"
  brew "fd"
  brew "gitui"
  brew "ripgrep"
end

# Python
brew "python"
brew "pyenv"

# Ruby
brew "ruby"
brew "chruby"

# Node.js
brew "n"

# Vim
brew "vim"

# Krypton
brew "kryptco/tap/kr" if OS.mac?
