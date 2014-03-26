# A librarian sample

A sample of librarian.

https://github.com/applicationsonline/librarian


## How To Build

    $ bundle install

## How To Use

Write your Foofile (like Gemfile).

    # Foofile
    site "https://github.com/haramako/librarian-foo-catalog"
    
    foo "test2"

    # specify version
    # foo "test1", "<~ 1.0.0"
    
    # locate in path
    # foo "test1", path: "/home/username/test1"
    
    # locate in git
    # foo "test1", git: "https://github.com/haramako/librarian-foo-test1.git"
    
    # locate in github
    # foo "test1", github: "haramako/librarian-foo-test1"
    

And run

    $ ./librarian-foo install


Then packages and dependencies are installed in `./foo` directory.


## License

Released under the terms of the MIT License. For further information, please see the file LICENSE.txt.
