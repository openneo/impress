class SafetyDepositPage < ClosetPage
  @selectors = {
    :items          => "#content tr[bgcolor=\"#DFEAF7\"]",
    :item_thumbnail => "img",
    :item_name      => "td:nth-child(2)",
    :item_quantity  => "td:nth-child(5)",
    :item_remove    => "input",
    :page_select    => "select[name=offset]",
    :selected       => "option[selected]"
  }

  def name
    'SDB'
  end

  def url
    "http://www.neopets.com/safetydeposit.phtml?offset=#{offset}"
  end

  protected

  REMOVE_NAME_REGEX = /\[([0-9]+)\]/
  def find_id(*args)
    name = super
    unless match = name.match(REMOVE_NAME_REGEX)
      raise ParseError, "Remove Item input name format was unexpected: #{name}.inspect"
    end
    match[1]
  end

  def find_index(*args)
    (super / 30) + 1
  end

  def offset
    @index ? (@index.to_i - 1) * 30 : 0
  end
end

