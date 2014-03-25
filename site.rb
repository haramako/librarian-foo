require 'fileutils'
require 'pathname'
require 'uri'
require 'net/https'
require 'json'
require 'digest'
require 'zlib'
require 'securerandom'
require 'archive/tar/minitar'
require 'open-uri'

require 'librarian/source/basic_api'

module Librarian
  module Foo
    module Source
      
      class Site

        class Line

          attr_accessor :source, :name
          private :source=, :name=

          def initialize(source, name)
            self.source = source
            self.name = name
            @repository = source.repository(name)
            @version_metadata = Hash.new
          end

          def install_version!(version, install_path)
            unpacked_path = cache_version_unpacked!(version)

            if install_path.exist?
              debug { "Deleting #{relative_path_to(install_path)}" }
              install_path.rmtree
            end

            debug { "Copying #{relative_path_to(unpacked_path)} to #{relative_path_to(install_path)}" }
            FileUtils.mv(unpacked_path, install_path)
          end

          def manifests
            versions.map do |version|
              Manifest.new(source, name, version)
            end
          end

          def version_dependencies(version)
            version_metadata(version)["dependencies"]
          end

        private

          def environment
            source.environment
          end

          def versions
            return @versions if @versons
            data = source.uncached_get("https://api.github.com/repos/#{repository}git/refs")
            versions = JSON.parse(data).map do |ref|
              (ref["ref"] =~ /^refs\/tags\/v(.+)$/) && $1
            end.delete_if(&:nil?)
            @versions = versions
          end

          def repository
            @repository
          end
          
          def version_metadata(version)
            return @version_metadata[version] if @version_metadata[version]
            _, json = source.cached_get("https://raw.githubusercontent.com/#{repository}v#{version}/metadata.json")
            @version_metadata[version] = JSON.parse(json)
          end

          def cache_version_unpacked!(version)
            cache, _ = source.cached_get("https://github.com/#{repository}archive/v#{version}.tar.gz")
            temp = environment.scratch_path.join(SecureRandom.hex(16))
            temp.mkpath
            
            debug { "Unpacking #{relative_path_to(cache)} to #{relative_path_to(temp)}" }
            Zlib::GzipReader.open(cache) do |input|
              Archive::Tar::Minitar.unpack(input, temp.to_s)
            end

            subtemps = temp.children
            subtemps.empty? and raise "The package archive was empty!"
            subtemps.delete_if{|pth| pth.to_s[/pax_global_header/]}
            subtemps.size > 1 and raise "The package archive has too many children!"
            subtemp = subtemps.first
            subtemp
          end

          def debug(*args, &block)
            environment.logger.debug(*args, &block)
          end

          def relative_path_to(path)
            environment.logger.relative_path_to(path)
          end

        end

        include Librarian::Source::BasicApi

        lock_name 'SITE'
        spec_options []

        attr_accessor :environment, :uri
        private :environment=, :uri=

        def initialize(environment, uri, options = {})
          self.environment = environment
          self.uri = uri
        end

        def to_s
          uri
        end

        def ==(other)
          other &&
          self.class  == other.class &&
          self.uri    == other.uri
        end

        def to_spec_args
          [uri, {}]
        end

        def to_lock_options
          {:remote => uri}
        end

        def pinned?
          false
        end

        def unpin!
        end

        def install!(manifest)
          manifest.source == self or raise ArgumentError

          name = manifest.name
          version = manifest.version
          install_path = install_path(name)
          line = line(name)

          info { "Installing #{manifest.name} (#{manifest.version})" }

          debug { "Installing #{manifest}" }

          line.install_version! version, install_path
        end

        # NOTE:
        #   Assumes the Opscode Site API responds with versions in reverse sorted order
        def manifests(name)
          line(name).manifests
        end

        def cache_path
          @cache_path ||= begin
            dir = Digest::MD5.hexdigest(uri)[0..15]
            environment.cache_path.join("source/foo/site/#{dir}")
          end
        end

        def install_path(name)
          environment.install_path.join(name)
        end

        def fetch_version(name, version)
          version
        end

        def fetch_dependencies(name, version, version_uri)
          line(name).version_dependencies(version).map{|k, v| Dependency.new(k, v, nil)}
        end

        MD_ = {
          "test1"=>"haramako/librarian-foo-test1/",
          "test2"=>"haramako/librarian-foo-test2/",
        }

        def repository(name)
          # return @catalog[name] if @catalog[name]
          if MD_[name]
            MD_[name]
          else
            name + '/'
          end
        end

        def uncached_get(uri)
          http_get(uri)
        end

        def cached_get(uri)
          path = cache_path + Digest::MD5.hexdigest(uri.to_s)
          if File.exists? path
            data = IO.binread(path)
          else
            debug { "Caching #{uri} to #{path}" }
            data = http_get(uri)
            cache_path.mkpath
            IO.binwrite path, data
          end
          [path, data]
        end

        def http_get(uri)
          uri = URI(uri) unless URI === uri
          uri.read
        end

      private

        def line(name)
          @line ||= { }
          @line[name] ||= Line.new(self, name)
        end

        def info(*args, &block)
          environment.logger.info(*args, &block)
        end

        def debug(*args, &block)
          environment.logger.debug(*args, &block)
        end

      end
    end
  end
end
