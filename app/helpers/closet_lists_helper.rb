module ClosetListsHelper
  def hangers_owned_options
    @hangers_owned_options ||= [true, false].map do |owned|
      verb = ClosetHanger.verb(:i, owned)
      ["items I #{verb}", owned]
    end
  end
end

