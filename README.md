# Tentacles

This is a WIP in early stage.

## Installation for development

### Prerequisites

A version manager for ruby and nodejs. This project is already configured to use [asdf](https://asdf-vm.com/). You can manage yourself the languages version installed on your machine.

if you are using a Homebrew on a mac, here is how you install asdf and the plugins required for this project:

```
brew install asdf
asdf plugin add ruby
asdf plugin add nodejs
```

You also need mysql installed and running.

```
brew install mysql
brew services start mysql
```

### Setup

```
git clone https://github.com/sophiedeziel/Tentacles.git
cd Tentacles
asdf install
bundle
yarn
```

## Update Gcode documentation

Run the following script from the project's root directory: 

```
rails gcode_documentation:fetch
```
