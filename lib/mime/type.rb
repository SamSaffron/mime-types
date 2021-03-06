require "mime/pooled_attr_accessor"

module MIME
  class Type
    include Comparable
    extend PooledAttrAccessor

    MEDIA_TYPE_RE = %r{([-\w.+]+)/([-\w.+]*)}o
    UNREG_RE      = %r{[Xx]-}o
    ENCODING_RE   = %r{(?:base64|7bit|8bit|quoted\-printable)}o
    PLATFORM_RE   = %r|#{RUBY_PLATFORM}|o

    SIGNATURES    = %w(application/pgp-keys application/pgp
                       application/pgp-signature application/pkcs10
                       application/pkcs7-mime application/pkcs7-signature
                       text/vcard)

    IANA_URL      = "http://www.iana.org/assignments/media-types/%s/%s"
    RFC_URL       = "http://rfc-editor.org/rfc/rfc%s.txt"
    DRAFT_URL     = "http://datatracker.ietf.org/public/idindex.cgi?command=id_details&filename=%s"
    LTSW_URL      = "http://www.ltsw.se/knbase/internet/%s.htp"
    CONTACT_URL   = "http://www.iana.org/assignments/contact-people.htm#%s"

    # Returns +true+ if the simplified type matches the current
    def like?(other)
      if other.respond_to?(:simplified)
        @simplified == other.simplified
      else
        @simplified == Type.simplified(other)
      end
    end

    # Compares the MIME::Type against the exact content type or the
    # simplified type (the simplified type will be used if comparing against
    # something that can be treated as a String with #to_s). In comparisons,
    # this is done against the lowercase version of the MIME::Type.
    def <=>(other)
      if other.respond_to?(:content_type)
        @content_type.downcase <=> other.content_type.downcase
      elsif other.respond_to?(:to_s)
        @simplified <=> Type.simplified(other.to_s)
      else
        @content_type.downcase <=> other.downcase
      end
    end

    # Compares the MIME::Type based on how reliable it is before doing a
    # normal <=> comparison. Used by MIME::Types#[] to sort types. The
    # comparisons involved are:
    #
    # 1. self.simplified <=> other.simplified (ensures that we
    #    don't try to compare different types)
    # 2. IANA-registered definitions < other definitions.
    # 3. Generic definitions < platform definitions.
    # 3. Complete definitions < incomplete definitions.
    # 4. Current definitions < obsolete definitions.
    # 5. Obselete with use-instead references < obsolete without.
    # 6. Obsolete use-instead definitions are compared.
    def priority_compare(other)
      pc = simplified <=> other.simplified

      if pc.zero?
        pc = if registered? != other.registered?
               registered? ? -1 : 1 # registered < unregistered
             elsif platform? != other.platform?
               platform? ? 1 : -1 # generic < platform
             elsif complete? != other.complete?
               pc = complete? ? -1 : 1 # complete < incomplete
             elsif obsolete? != other.obsolete?
               pc = obsolete? ? 1 : -1 # current < obsolete
             end

        if pc.zero? and obsolete? and (use_instead != other.use_instead)
          pc = if use_instead.nil?
                 -1
               elsif other.use_instead.nil?
                 1
               else
                 use_instead <=> other.use_instead
               end
        end
      end

      pc
    end

    # Returns +true+ if the other object is a MIME::Type and the content
    # types match.
    def eql?(other)
      other.kind_of?(MIME::Type) and self == other
    end

    # Returns the whole MIME content-type string.
    #
    #   text/plain        => text/plain
    #   x-chemical/x-pdb  => x-chemical/x-pdb
    pooled_attr_accessor :content_type, private_writer: true
    # Returns the media type of the simplified MIME type.
    #
    #   text/plain        => text
    #   x-chemical/x-pdb  => chemical
    pooled_attr_accessor :media_type, private_writer: true

    # Returns the media type of the unmodified MIME type.
    #
    #   text/plain        => text
    #   x-chemical/x-pdb  => x-chemical
    pooled_attr_accessor :raw_media_type, private_writer: true

    # Returns the sub-type of the simplified MIME type.
    #
    #   text/plain        => plain
    #   x-chemical/x-pdb  => pdb
    pooled_attr_accessor :sub_type, private_writer: true

    # Returns the media type of the unmodified MIME type.
    #
    #   text/plain        => plain
    #   x-chemical/x-pdb  => x-pdb
    pooled_attr_accessor :raw_sub_type, private_writer: true

    # The MIME types main- and sub-label can both start with <tt>x-</tt>,
    # which indicates that it is a non-registered name. Of course, after
    # registration this flag can disappear, adds to the confusing
    # proliferation of MIME types. The simplified string has the <tt>x-</tt>
    # removed and are translated to lowercase.
    #
    #   text/plain        => text/plain
    #   x-chemical/x-pdb  => chemical/pdb
    pooled_attr_accessor :simplified, private_writer: true

    # The list of extensions which are known to be used for this MIME::Type.
    # Non-array values will be coerced into an array with #to_a. Array
    # values will be flattened and +nil+ values removed.
    attr_reader :extensions

    def extensions=(ext)
      @extensions = [ext].flatten.compact.map { |e| ValuePool[e] }
    end

    # The encoding (7bit, 8bit, quoted-printable, or base64) required to
    # transport the data of this content type safely across a network, which
    # roughly corresponds to Content-Transfer-Encoding. A value of +nil+ or
    # <tt>:default</tt> will reset the #encoding to the #default_encoding
    # for the MIME::Type. Raises ArgumentError if the encoding provided is
    # invalid.
    #
    # If the encoding is not provided on construction, this will be either
    # 'quoted-printable' (for text/* media types) and 'base64' for eveything
    # else.
    attr_reader :encoding

    def encoding=(enc) #:nodoc:
      if enc.nil? or enc == :default
        @encoding = ValuePool[default_encoding]
      elsif enc =~ ENCODING_RE
        @encoding = ValuePool[enc]
      else
        raise ArgumentError, "The encoding must be nil, :default, base64, 7bit, 8bit, or quoted-printable."
      end
    end

    # The regexp for the operating system that this MIME::Type is specific
    # to.
    attr_reader :system

    def system=(os) #:nodoc:
      @system = ValuePool[
        if os.nil? or os.kind_of?(Regexp)
          os
        else
          %r|#{os}|
        end
      ]
    end

    # Returns the default encoding for the MIME::Type based on the media
    # type.
    attr_reader :default_encoding

    TEXT = "text".freeze
    QUOTED_PRINTABLE = "quoted-printable".freeze
    BASE64 = "base64".freeze
    private_constant :TEXT, :QUOTED_PRINTABLE, :BASE64

    def default_encoding
      (@media_type == TEXT) ? QUOTED_PRINTABLE : BASE64
    end

    # Returns the media type or types that should be used instead of this
    # media type, if it is obsolete. If there is no replacement media type,
    # or it is not obsolete, +nil+ will be returned.
    def use_instead
      return nil unless @obsolete
      @use_instead
    end

    # Returns +true+ if the media type is obsolete.
    def obsolete?
      @obsolete ? true : false
    end

    # Sets the obsolescence indicator for this media type.
    attr_writer :obsolete

    # The documentation for this MIME::Type. Documentation about media
    # types will be found on a media type definition as a comment.
    # Documentation will be found through #docs.
    attr_reader :docs

    def docs=(d)
      if d
        a = d.scan(%r{use-instead:#{MEDIA_TYPE_RE}})

        if a.empty?
          @use_instead = nil
        else
          @use_instead = a.map { |el| ValuePool["#{el[0]}/#{el[1]}"] }
        end
      end
      @docs = ValuePool[d]
    end

    # The encoded URL list for this MIME::Type. See #urls for more
    # information.
    attr_reader :url

    def url=(url)
      @url = url.is_a?(Array) ? url.map { |u| ValuePool[u] } : url
    end

    # The decoded URL list for this MIME::Type.
    # The special URL value IANA will be translated into:
    #   http://www.iana.org/assignments/media-types/<mediatype>/<subtype>
    #
    # The special URL value RFC### will be translated into:
    #   http://www.rfc-editor.org/rfc/rfc###.txt
    #
    # The special URL value DRAFT:name will be translated into:
    #   https://datatracker.ietf.org/public/idindex.cgi?
    #       command=id_detail&filename=<name>
    #
    # The special URL value LTSW will be translated into:
    #   http://www.ltsw.se/knbase/internet/<mediatype>.htp
    #
    # The special URL value [token] will be translated into:
    #   http://www.iana.org/assignments/contact-people.htm#<token>
    #
    # These values will be accessible through #urls, which always returns an
    # array.
    def urls
      @url.map do |el|
        case el
        when %r{^IANA$}
          IANA_URL % [ @media_type, @sub_type ]
        when %r{^RFC(\d+)$}
          RFC_URL % $1
        when %r{^DRAFT:(.+)$}
          DRAFT_URL % $1
        when %r{^LTSW$}
          LTSW_URL % @media_type
        when %r{^\{([^=]+)=([^\}]+)\}}
          [$1, $2]
        when %r{^\[([^=]+)=([^\]]+)\]}
          [$1, CONTACT_URL % $2]
        when %r{^\[([^\]]+)\]}
          CONTACT_URL % $1
        else
          el
        end
      end
    end

    class << self
      # The MIME types main- and sub-label can both start with <tt>x-</tt>,
      # which indicates that it is a non-registered name. Of course, after
      # registration this flag can disappear, adds to the confusing
      # proliferation of MIME types. The simplified string has the
      # <tt>x-</tt> removed and are translated to lowercase.
      def simplified(content_type)
        matchdata = MEDIA_TYPE_RE.match(content_type)

        if matchdata.nil?
          simplified = nil
        else
          media_type = matchdata.captures[0].downcase.gsub(UNREG_RE, '')
          subtype = matchdata.captures[1].downcase.gsub(UNREG_RE, '')
          simplified = "#{media_type}/#{subtype}"
        end
        simplified
      end

      # Creates a MIME::Type from an array in the form of:
      #   [type-name, [extensions], encoding, system]
      #
      # +extensions+, +encoding+, and +system+ are optional.
      #
      #   MIME::Type.from_array("application/x-ruby", ['rb'], '8bit')
      #   MIME::Type.from_array(["application/x-ruby", ['rb'], '8bit'])
      #
      # These are equivalent to:
      #
      #   MIME::Type.new('application/x-ruby') do |t|
      #     t.extensions  = %w(rb)
      #     t.encoding    = '8bit'
      #   end
      def from_array(*args) #:yields MIME::Type.new:
        # Dereferences the array one level, if necessary.
        args = args.first if args.first.kind_of? Array

        unless args.size.between?(1, 8)
          raise ArgumentError, "Array provided must contain between one and eight elements."
        end

        MIME::Type.new(args.shift) do |t|
          t.extensions, t.encoding, t.system, t.obsolete, t.docs, t.url,
            t.registered = *args
          yield t if block_given?
        end
      end

      # Creates a MIME::Type from a hash. Keys are case-insensitive,
      # dashes may be replaced with underscores, and the internal Symbol
      # of the lowercase-underscore version can be used as well. That is,
      # Content-Type can be provided as content-type, Content_Type,
      # content_type, or :content_type.
      #
      # Known keys are <tt>Content-Type</tt>,
      # <tt>Content-Transfer-Encoding</tt>, <tt>Extensions</tt>, and
      # <tt>System</tt>.
      #
      #   MIME::Type.from_hash('Content-Type' => 'text/x-yaml',
      #                        'Content-Transfer-Encoding' => '8bit',
      #                        'System' => 'linux',
      #                        'Extensions' => ['yaml', 'yml'])
      #
      # This is equivalent to:
      #
      #   MIME::Type.new('text/x-yaml') do |t|
      #     t.encoding    = '8bit'
      #     t.system      = 'linux'
      #     t.extensions  = ['yaml', 'yml']
      #   end
      def from_hash(hash) #:yields MIME::Type.new:
        type = {}
        hash.each_pair do |k, v|
          type[k.to_s.tr('A-Z', 'a-z').gsub(/-/, '_').to_sym] = v
        end

        MIME::Type.new(type[:content_type]) do |t|
          t.extensions  = type[:extensions]
          t.encoding    = type[:content_transfer_encoding]
          t.system      = type[:system]
          t.obsolete    = type[:obsolete]
          t.docs        = type[:docs]
          t.url         = type[:url]
          t.registered  = type[:registered]

          yield t if block_given?
        end
      end

      # Essentially a copy constructor.
      #
      #   MIME::Type.from_mime_type(plaintext)
      #
      # is equivalent to:
      #
      #   MIME::Type.new(plaintext.content_type.dup) do |t|
      #     t.extensions  = plaintext.extensions.dup
      #     t.system      = plaintext.system.dup
      #     t.encoding    = plaintext.encoding.dup
      #   end
      def from_mime_type(mime_type) #:yields the new MIME::Type:
        MIME::Type.new(mime_type.content_type.dup) do |t|
          t.extensions = mime_type.extensions.map { |e| e.dup }
          t.url = mime_type.url && mime_type.url.map { |e| e.dup }

          mime_type.system && t.system = mime_type.system.dup
          mime_type.encoding && t.encoding = mime_type.encoding.dup

          t.obsolete = mime_type.obsolete?
          t.registered = mime_type.registered?

          mime_type.docs && t.docs = mime_type.docs.dup

          yield t if block_given?
        end
      end
    end

    # Builds a MIME::Type object from the provided MIME Content Type value
    # (e.g., 'text/plain' or 'applicaton/x-eruby'). The constructed object
    # is yielded to an optional block for additional configuration, such as
    # associating extensions and encoding information.
    def initialize(content_type) #:yields self:
      matchdata = MEDIA_TYPE_RE.match(content_type)

      if matchdata.nil?
        raise InvalidContentType, "Invalid Content-Type provided ('#{content_type}')"
      end

      self.content_type = content_type
      self.raw_media_type = matchdata.captures[0]
      self.raw_sub_type = matchdata.captures[1]

      self.simplified = MIME::Type.simplified(@content_type)
      matchdata = MEDIA_TYPE_RE.match(@simplified)
      self.media_type = matchdata.captures[0]
      self.sub_type = matchdata.captures[1]

      self.extensions   = nil
      self.encoding     = :default
      self.system       = nil
      self.registered   = true
      self.url          = nil
      self.obsolete     = nil
      self.docs         = nil

      yield self if block_given?
    end

    # MIME content-types which are not regestered by IANA nor defined in
    # RFCs are required to start with <tt>x-</tt>. This counts as well for
    # a new media type as well as a new sub-type of an existing media
    # type. If either the media-type or the content-type begins with
    # <tt>x-</tt>, this method will return +false+.
    def registered?
      if (@raw_media_type =~ UNREG_RE) || (@raw_sub_type =~ UNREG_RE)
        false
      else
        @registered
      end
    end
    attr_writer :registered #:nodoc:

    # MIME types can be specified to be sent across a network in particular
    # formats. This method returns +true+ when the MIME type encoding is set
    # to <tt>base64</tt>.
    def binary?
      @encoding == BASE64
    end

    # MIME types can be specified to be sent across a network in particular
    # formats. This method returns +false+ when the MIME type encoding is
    # set to <tt>base64</tt>.
    def ascii?
      not binary?
    end

    # Returns +true+ when the simplified MIME type is in the list of known
    # digital signatures.
    def signature?
      SIGNATURES.include?(@simplified.downcase)
    end

    # Returns +true+ if the MIME::Type is specific to an operating system.
    def system?
      not @system.nil?
    end

    # Returns +true+ if the MIME::Type is specific to the current operating
    # system as represented by RUBY_PLATFORM.
    def platform?
      system? and (RUBY_PLATFORM =~ @system)
    end

    # Returns +true+ if the MIME::Type specifies an extension list,
    # indicating that it is a complete MIME::Type.
    def complete?
      not @extensions.empty?
    end

    # Returns the MIME type as a string.
    def to_s
      @content_type
    end

    # Returns the MIME type as a string for implicit conversions.
    def to_str
      @content_type
    end

    # Returns the MIME type as an array suitable for use with
    # MIME::Type.from_array.
    def to_a
      [ @content_type, @extensions, @encoding, @system, @obsolete, @docs,
        @url, registered? ]
    end

    # Returns the MIME type as an array suitable for use with
    # MIME::Type.from_hash.
    def to_hash
      { 'Content-Type'              => @content_type,
        'Content-Transfer-Encoding' => @encoding,
        'Extensions'                => @extensions,
        'System'                    => @system,
        'Obsolete'                  => @obsolete,
        'Docs'                      => @docs,
        'URL'                       => @url,
        'Registered'                => registered?,
      }
    end
  end
end
