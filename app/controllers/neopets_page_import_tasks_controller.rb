class NeopetsPageImportTasksController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_filter :authenticate_user!

  before_filter :require_source, only: [:create]

  rescue_from NeopetsPage::ParseError, with: :on_parse_error

  def create
    neopets_page = NeopetsPage.new(params[:page_type], params[:expected_index].to_i, params[:neopets_page][:source])

    @import_task = neopets_page.build_import_task(current_user, params[:neopets_page_import_task][:list_id])

    messages = [tt('success', index: neopets_page.index)]

    results = @import_task.save
    any_created = results[:counts][:created] > 0
    any_updated = results[:counts][:updated] > 0
    any_unchanged = results[:counts][:unchanged] > 0

    if any_created && any_updated
      created_msg = tt('created_and_updated_hangers.created_msg',
                       count: results[:counts][:created])
      updated_msg = tt('created_and_updated_hangers.updated_msg',
                       count: results[:counts][:updated])
      messages << tt('created_and_updated_hangers.text',
                     created_msg: created_msg,
                     updated_msg: updated_msg)
    elsif any_created
      messages << tt('created_hangers',
                     count: results[:counts][:created])
    elsif any_updated
      messages << tt('updated_hangers',
                     count: results[:counts][:updated])
    elsif any_unchanged
      messages << tt('no_changes')
    else
      messages << tt('no_data')
    end

    unless results[:unknown_item_names].empty?
      messages << tt('unknown_items',
                     item_names: results[:unknown_item_names].to_sentence,
                     count: results[:unknown_item_names].size)
    end

    if neopets_page.last?
      messages << tt('done', name: neopets_page.name)
      destination = user_closet_hangers_path(current_user)
    else
      messages << tt('next_page',
                     next_index: (neopets_page.index + 1))
      destination = new_neopets_page_import_task_path(
        expected_index: neopets_page.index + 1, list_id: @import_task.list_id)
    end

    flash[:success] = messages.join(' ')
    redirect_to destination
  end

  def new
    neopets_page = NeopetsPage.new(params[:page_type], params[:expected_index].to_i, nil)
    @import_task = neopets_page.build_import_task(current_user, params[:list_id])
  end

  def tt(key, params={})
    t("neopets_page_import_tasks.create.#{key}", params)
  end

  def require_source
    redirect_to(action: :new) if params[:neopets_page][:source].empty?
  end

  protected

  def on_parse_error(e)
    Rails.logger.info "Neopets page parse error: #{e.message}"
    flash[:alert] = tt('parse_error')
    render action: :new
  end
end

