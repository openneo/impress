if String.method_defined?(:force_encoding)
  # UTF-8 support is native, so let's route the +"abc" syntax to the native
  # encode method.

  class String
    def +@
      force_encoding('utf-8')
    end
  end
else
  require 'encoding/character/utf-8'
end

