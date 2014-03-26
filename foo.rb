#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'librarian/cli'
require 'json'
require 'yaml'
require 'pp'
require_relative 'source'
require_relative 'site'

module Librarian
  module Foo
    extend self
    extend Librarian

    VERSION = "0.0.1"
    
    class Cli < Librarian::Cli

      module Particularity
        def root_module
          Foo
        end
      end

      extend Particularity

      # copy_file で使用されるテンプレートを格納したパス
      source_root File.expand_path('../templates', __FILE__)
      
      # '$ ./librarian-foo init' 時に呼ばれる
      def init
        copy_file environment.specfile_name
      end

      desc "install", "Resolves and installs all of the dependencies you specify."
      option "quiet", :type => :boolean, :default => false
      option "verbose", :type => :boolean, :default => false
      
      # '$ ./librarian-foo init' 時に呼ばれる
      def install
        ensure!
        resolve!
        install!
      end

    end
      
    class Environment < Librarian::Environment

      def adapter_name
        "foo"
      end

      def adapter_version
        VERSION
      end

      def install_path
        project_path.join("foo")
      end

    end

    class Dsl < Librarian::Dsl

      dependency :foo

      source :site => Source::Site
      source :git => Source::Git
      source :github => Source::Github
      source :path => Source::Path
      source :local => Source::Path
    end

    module ManifestReader
      extend self

      MANIFESTS = %w(metadata.json metadata.yml metadata.yaml)

      def manifest_path(path)
        MANIFESTS.map{|s| path.join(s)}.find{|s| s.exist?}
      end

      def read_manifest(name, manifest_path)
        case manifest_path.extname
        when ".json" then JSON.parse(IO.binread(manifest_path))
        when ".yml", ".yaml" then YAML.load(IO.binread(manifest_path))
        end
      end

      def manifest?(name, path)
        path = Pathname.new(path)
        !!manifest_path(path)
      end

    end
    
  end
end

