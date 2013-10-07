# Nitpicker

Frugal continuous integration tool.

Nitpicker will sequentially build every projects it is told to.

The main goal is to avoid the burden of running multiple builds at once.

## What can Nitpicker do?

* Nitpicker can update projects from git.
* Nitpicker can detect the .ruby-version files and use rvm to run the build with the proper ruby version.
* Nitpicker can build a project and tell when the build fails or succeed.
* Nitpicker can put everything in a log file.

## Install

* Checkout nitpicker from github.
* Create a 'work' directory.
* Put your projects in the work directory.
* Add an executable 'script/build' in your project.
* Install the nitpicker bundle.
* Run nitpicker.
