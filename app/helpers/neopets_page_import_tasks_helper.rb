module NeopetsPageImportTasksHelper
  def neopets_page_list_options(user)
    lists = user.closet_lists.group_by(&:hangers_owned?)
    options = []
    [true, false].each do |owned|
      relevant_lists = lists[owned] || []
      options << [closet_lists_group_name(:you, owned), owned]
      options += relevant_lists.map { |list| ["&mdash;#{h list.name}".html_safe, list.id] }
    end
    options
  end
end