# coding: utf-8
require "mime/type"

# The namespace for MIME applications, tools, and libraries.
module MIME
  # Reflects a MIME Content-Type which is in invalid format (e.g., it isn't
  # in the form of type/subtype).
  class InvalidContentType < RuntimeError; end

  # = MIME::Types
  # MIME types are used in MIME-compliant communications, as in e-mail or
  # HTTP traffic, to indicate the type of content which is transmitted.
  # MIME::Types provides the ability for detailed information about MIME
  # entities (provided as a set of MIME::Type objects) to be determined and
  # used programmatically. There are many types defined by RFCs and vendors,
  # so the list is long but not complete; don't hesitate to ask to add
  # additional information. This library follows the IANA collection of MIME
  # types (see below for reference).
  #
  # == Description
  # MIME types are used in MIME entities, as in email or HTTP traffic. It is
  # useful at times to have information available about MIME types (or,
  # inversely, about files). A MIME::Type stores the known information about
  # one MIME type.
  #
  # == Usage
  #  require 'mime/types'
  #
  #  plaintext = MIME::Types['text/plain']
  #  print plaintext.media_type           # => 'text'
  #  print plaintext.sub_type             # => 'plain'
  #
  #  puts plaintext.extensions.join(" ")  # => 'asc txt c cc h hh cpp'
  #
  #  puts plaintext.encoding              # => 8bit
  #  puts plaintext.binary?               # => false
  #  puts plaintext.ascii?                # => true
  #  puts plaintext.obsolete?             # => false
  #  puts plaintext.registered?           # => true
  #  puts plaintext == 'text/plain'       # => true
  #  puts MIME::Type.simplified('x-appl/x-zip') # => 'appl/zip'
  #
  # This module is built to conform to the MIME types of RFCs 2045 and 2231.
  # It follows the official IANA registry at
  # http://www.iana.org/assignments/media-types/ and
  # ftp://ftp.iana.org/assignments/media-types with some unofficial types
  # added from the the collection at
  # http://www.ltsw.se/knbase/internet/mime.htp
  #
  # This is originally based on Perl MIME::Types by Mark Overmeer.
  #
  # = Author
  # Copyright:: Copyright 2002–2013 by Austin Ziegler
  #             <austin@rubyforge.org>
  # Version::   1.20.1
  # Licence::   See Licence.rdoc
  # See Also::  http://www.iana.org/assignments/media-types/
  #             http://www.ltsw.se/knbase/internet/mime.htp
  #
  class Types
    def initialize
      @type_variants    = Hash.new { |h, k| h[k] = [] }
      @extension_index  = Hash.new { |h, k| h[k] = [] }
    end

    def add_type_variant(mime_type) #:nodoc:
      @type_variants[mime_type.simplified] << mime_type
    end

    def index_extensions(mime_type) #:nodoc:
      mime_type.extensions.each { |ext| @extension_index[ext] << mime_type }
    end

    def defined_types #:nodoc:
      @type_variants.values.flatten
    end
  
    # Returns the number of known types. A shortcut of MIME::Types[//].size.
    # (Keep in mind that this is memory intensive, cache the result to spare
    # resources)
    def count
      defined_types.size
    end
  
    def each
      return enum_for(:each) unless block_given?

      defined_types.each { |t| yield t }
    end

    @__types__ = self.new

    # Returns a list of MIME::Type objects, which may be empty. The optional
    # flag parameters are :complete (finds only complete MIME::Type objects)
    # and :platform (finds only MIME::Types for the current platform). It is
    # possible for multiple matches to be returned for either type (in the
    # example below, 'text/plain' returns two values -- one for the general
    # case, and one for VMS systems.
    #
    #   puts "\nMIME::Types['text/plain']"
    #   MIME::Types['text/plain'].each { |t| puts t.to_a.join(", ") }
    #
    #   puts "\nMIME::Types[/^image/, :complete => true]"
    #   MIME::Types[/^image/, :complete => true].each do |t|
    #     puts t.to_a.join(", ")
    #   end
    #
    # If multiple type definitions are returned, returns them sorted as
    # follows:
    #   1. Complete definitions sort before incomplete ones;
    #   2. IANA-registered definitions sort before LTSW-recorded
    #      definitions.
    #   3. Generic definitions sort before platform-specific ones;
    #   4. Current definitions sort before obsolete ones;
    #   5. Obsolete definitions with use-instead clauses sort before those
    #      without;
    #   6. Obsolete definitions use-instead clauses are compared.
    #   7. Sort on name.
    def [](type_id, flags = {})
      if type_id.kind_of?(Regexp)
        matches = []
        @type_variants.each_key do |k|
          matches << @type_variants[k] if k =~ type_id
        end
        matches.flatten!
      elsif type_id.kind_of?(MIME::Type)
        matches = [type_id]
      else
        matches = @type_variants[MIME::Type.simplified(type_id)]
      end

      matches.delete_if { |e| not e.complete? } if flags[:complete]
      matches.delete_if { |e| not e.platform? } if flags[:platform]

      matches.sort { |a, b| a.priority_compare(b) }
    end

    # Return the list of MIME::Types which belongs to the file based on its
    # filename extension. If +platform+ is +true+, then only file types that
    # are specific to the current platform will be returned.
    #
    # This will always return an array.
    #
    #   puts "MIME::Types.type_for('citydesk.xml')
    #     => [application/xml, text/xml]
    #   puts "MIME::Types.type_for('citydesk.gif')
    #     => [image/gif]
    def type_for(filename, platform = false)
      ext = filename.chomp.downcase.gsub(/.*\./o, '')
      list = @extension_index[ext]
      list.delete_if { |e| not e.platform? } if platform
      list
    end

    # A synonym for MIME::Types.type_for
    def of(filename, platform = false)
      type_for(filename, platform)
    end

    # Add one or more MIME::Type objects to the set of known types. Each
    # type should be experimental (e.g., 'application/x-ruby'). If the type
    # is already known, a warning will be displayed.
    #
    # <strong>Please inform the maintainer of this module when registered
    # types are missing.</strong>
    def add(*types)
      types.each do |mime_type|
        if mime_type.kind_of? MIME::Types
          add(*mime_type.defined_types)
        else
          if @type_variants.include?(mime_type.simplified)
            if @type_variants[mime_type.simplified].include?(mime_type)
              warn "Type #{mime_type} already registered as a variant of #{mime_type.simplified}." unless defined? MIME::Types::STARTUP
            end
          end
          add_type_variant(mime_type)
          index_extensions(mime_type)
        end
      end
    end

    class << self
      def add_type_variant(mime_type) #:nodoc:
        @__types__.add_type_variant(mime_type)
      end

      def index_extensions(mime_type) #:nodoc:
        @__types__.index_extensions(mime_type)
      end

      # The regular expression used to match a file-based MIME type
      # definition.
      TEXT_FORMAT_RE = %r{
        \A
        \s*
        ([*])?                                 # 0: Unregistered?
        (!)?                                   # 1: Obsolete?
        (?:(\w+):)?                            # 2: Platform marker
        #{MIME::Type::MEDIA_TYPE_RE}?          # 3,4: Media type
        (?:\s+@([^\s]+))?                      # 5: Extensions
        (?:\s+:(#{MIME::Type::ENCODING_RE}))?  # 6: Encoding
        (?:\s+'(.+))?                          # 7: URL list
        (?:\s+=(.+))?                          # 8: Documentation
        (?:\s*([#].*)?)?
        \s*
        \z
      }x

      # Build the type list from a file in the format:
      #
      #   [*][!][os:]mt/st[<ws>@ext][<ws>:enc][<ws>'url-list][<ws>=docs]
      #
      # == *
      # An unofficial MIME type. This should be used if and only if the MIME type
      # is not properly specified (that is, not under either x-type or
      # vnd.name.type).
      #
      # == !
      # An obsolete MIME type. May be used with an unofficial MIME type.
      #
      # == os:
      # Platform-specific MIME type definition.
      #
      # == mt
      # The media type.
      #
      # == st
      # The media subtype.
      #
      # == <ws>@ext
      # The list of comma-separated extensions.
      #
      # == <ws>:enc
      # The encoding.
      #
      # == <ws>'url-list
      # The list of comma-separated URLs.
      #
      # == <ws>=docs
      # The documentation string.
      #
      # That is, everything except the media type and the subtype is optional. The
      # more information that's available, though, the richer the values that can
      # be provided.
      def load_from_file(filename) #:nodoc:
        if defined? ::Encoding
          data = File.open(filename, 'r:UTF-8') { |f| f.read }
        else
          data = File.open(filename) { |f| f.read }
        end
        data = data.split($/)
        mime = MIME::Types.new
        data.each_with_index { |line, index|
          item = line.chomp.strip
          next if item.empty?

          begin
            m = TEXT_FORMAT_RE.match(item).captures
          rescue Exception
            puts "#{filename}:#{index}: Parsing error in MIME type definitions."
            puts "=> #{line}"
            raise
          end

          unregistered, obsolete, platform, mediatype, subtype, extensions,
            encoding, urls, docs, comment = *m

          if mediatype.nil?
            if comment.nil?
              puts "#{filename}:#{index}: Parsing error in MIME type definitions."
              puts "=> #{line}"
              raise RuntimeError
            end

            next
          end

          extensions &&= extensions.split(/,/)
          urls &&= urls.split(/,/)

          mime_type = MIME::Type.new("#{mediatype}/#{subtype}") do |t|
            t.extensions  = extensions
            t.encoding    = encoding
            t.system      = platform
            t.obsolete    = obsolete
            t.registered  = false if unregistered
            t.docs        = docs
            t.url         = urls
          end

          mime.add(mime_type)
        }
        mime
      end

      # Returns a list of MIME::Type objects, which may be empty. The
      # optional flag parameters are :complete (finds only complete
      # MIME::Type objects) and :platform (finds only MIME::Types for the
      # current platform). It is possible for multiple matches to be
      # returned for either type (in the example below, 'text/plain' returns
      # two values -- one for the general case, and one for VMS systems.
      #
      #   puts "\nMIME::Types['text/plain']"
      #   MIME::Types['text/plain'].each { |t| puts t.to_a.join(", ") }
      #
      #   puts "\nMIME::Types[/^image/, :complete => true]"
      #   MIME::Types[/^image/, :complete => true].each do |t|
      #     puts t.to_a.join(", ")
      #   end
      def [](type_id, flags = {})
        @__types__[type_id, flags]
      end

      include Enumerable
  
      def count
        @__types__.count
      end

      def each
        return enum_for(:each) unless block_given?

        @__types__.each {|t| yield t }
      end

      # Return the list of MIME::Types which belongs to the file based on
      # its filename extension. If +platform+ is +true+, then only file
      # types that are specific to the current platform will be returned.
      #
      # This will always return an array.
      #
      #   puts "MIME::Types.type_for('citydesk.xml')
      #     => [application/xml, text/xml]
      #   puts "MIME::Types.type_for('citydesk.gif')
      #     => [image/gif]
      def type_for(filename, platform = false)
        @__types__.type_for(filename, platform)
      end

      # A synonym for MIME::Types.type_for
      def of(filename, platform = false)
        @__types__.type_for(filename, platform)
      end

      # Add one or more MIME::Type objects to the set of known types. Each
      # type should be experimental (e.g., 'application/x-ruby'). If the
      # type is already known, a warning will be displayed.
      #
      # <strong>Please inform the maintainer of this module when registered
      # types are missing.</strong>
      def add(*types)
        @__types__.add(*types)
      end
    end

    files = Dir[File.join(File.dirname(__FILE__), 'types', '*')]
    MIME::Types::STARTUP = true unless $DEBUG
    files.sort.each { |file| add load_from_file(file) }
    remove_const :STARTUP if defined? STARTUP
  end
end

# vim: ft=ruby
