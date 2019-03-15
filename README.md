# Rhythmbox
Music player controlled by device acceleration changes. 

# Installation
First you need to install [Git Large File Storage](https://git-lfs.github.com/) command line extensions so that pods are installed properly. Run:
```
brew install git-lfs
```
The project depends on pods created recently. You may also need to update local clone of the spec-repo so that Cocoapods knows about their existence. Run:
```
pod repo update
pod install
```
or
```
pod install --repo-update
```

# Usage
By default the model is trained to recognize taps on upper part of device back. Hold lower part of the phone with your left hand then tap with your right hand.

| Pattern | Action         |
|---------|----------------|
| 1 tap   | Play/Pause     |
| 2 taps  | Next track     |
| 3 taps  | Previous track |

You can record your own patterns and train model on them if you like. For more information please refer to in-app info hints.

