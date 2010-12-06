module HeadJsHelper
  JAVASCRIPT_LIBRARIES = {}
  YAML.load_file(Rails.root.join('config', 'javascript_libraries.yml')).each do |name, src|
    JAVASCRIPT_LIBRARIES[name.to_sym] = src
  end
  
  def html5
    content_for :html5, "<!--[if lt IE 9]>#{javascript_tag(JAVASCRIPT_LIBRARIES[:html5])}<![endif]-->".html_safe
  end
  
  def javascript_chain(*javascripts)
    # two-dimensional array: list of chains
    @javascript_chains ||= []
    @javascript_chains << javascripts
  end
  
  def javascript_chains
    if @javascript_chains
      javascript_include_tag('head') + "\n" + javascript_chains_tag(@javascript_chains)
    end
  end
  
  def javascript_chain_line(chain)
    chain_args = chain.map {
      |script_name| javascript_library_path(script_name).inspect
    }.join(', ')
    "head.js(#{chain_args});"
  end
  
  def javascript_chains_tag(chains)
    output_js do |js|
      chains.each do |chain|
        js << javascript_chain_line(chain)
      end
    end
  end
  
  private
  
  def javascript_library_path(script_name)
    script_name.is_a?(Symbol) ? JAVASCRIPT_LIBRARIES[script_name] : javascript_path(script_name)
  end
  
  def output_js(&block)
    javascript_tag(safe_output(&block))
  end
  
  def safe_output(&block)
    [].tap(&block).join("\n").html_safe
  end
end
