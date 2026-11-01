# frozen_string_literal: true

module AccountsPayable
  # Load only reviewed, locally vendored SAT templates. Never resolve remote XSLT.
  class SatStylesheetLoader
    INCLUDE = %r{<xsl:include\s+href="([^"]+)"\s*/>}
    SAFE_PATH = %r{\Axslt/[A-Za-z0-9_./-]+\.xslt\z}

    def self.call(stylesheet:)
      File.read(stylesheet).gsub(INCLUDE) do
        expand!(stylesheet, Regexp.last_match(1))
      end
    end

    def self.expand!(stylesheet, href)
      if !SAFE_PATH.match?(href) || href.split('/').include?('..')
        raise ArgumentError, 'Unsafe CFDI stylesheet dependency'
      end

      file = stylesheet.dirname.join(href)
      raise ArgumentError, 'Missing offline SAT stylesheet dependency' unless file.file?

      template_body!(File.read(file))
    end

    def self.template_body!(source)
      start_tag = source.index('<xsl:stylesheet')
      end_tag = source.rindex('</xsl:stylesheet>')
      raise ArgumentError, 'Invalid offline SAT stylesheet dependency' unless start_tag && end_tag

      open_tag = source.index('>', start_tag)
      raise ArgumentError, 'Invalid offline SAT stylesheet dependency' unless open_tag

      body = source[(open_tag + 1)...end_tag]
      raise ArgumentError, 'Nested SAT stylesheet dependency is not allowed' if body.match?(/<xsl:(?:include|import)\b/)

      body
    end
  end
end
