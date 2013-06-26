class NeopetsPagesController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_filter :authenticate_user!, :build_neopets_page

  rescue_from ClosetPage::ParseError, with: :on_parse_error

  def create
    if @page_params && @page_params[:source]
      @neopets_page.index = @page_params[:index]
      @neopets_page.list_id = @page_params[:list_id]
      @neopets_page.source = @page_params[:source]

      messages = [t('neopets_pages.create.success',
                    index: @neopets_page.index)]

      saved_counts = @neopets_page.save_hangers!
      any_created = saved_counts[:created] > 0
      any_updated = saved_counts[:updated] > 0
      if any_created && any_updated
        created_msg = t('neopets_pages.create.created_and_updated_hangers.created_msg',
                        count: saved_counts[:created])
        updated_msg = t('neopets_pages.create.created_and_updated_hangers.updated_msg',
                        count: saved_counts[:updated])
        messages << t('neopets_pages.create.created_and_updated_hangers.text',
                      created_msg: created_msg,
                      updated_msg: updated_msg)
      elsif any_created
        messages << t('neopets_pages.create.created_hangers',
                      count: saved_counts[:created])
      elsif any_updated
        messages << t('neopets_pages.create.updated_hangers',
                      count: saved_counts[:updated])
      elsif @neopets_page.hangers.size > 1 # saw items, but at same quantities
        messages << t('neopets_pages.create.no_changes')
      else # no items recognized
        messages << t('neopets_pages.create.no_data')
      end

      unless @neopets_page.unknown_item_names.empty?
        messages << t('neopets_pages.create.unknown_items',
                      item_names: @neopets_page.unknown_item_names.to_sentence,
                      count: @neopets_page.unknown_item_names.size)
      end

      if @neopets_page.last?
        messages << t('neopets_pages.create.done', name: @neopets_page.name)
        destination = user_closet_hangers_path(current_user)
      else
        messages << t('neopets_pages.create.next_page',
                      next_index: (@neopets_page.index + 1))
        destination = {action: :new, index: @neopets_page.index + 1,
                       list_id: @neopets_page.list_id}
      end

      flash[:success] = messages.join(' ')
      redirect_to destination
    else
      redirect_to action: :new
    end
  end

  def new
    @neopets_page.index ||= 1
  end

  protected

  TYPES = {
    'closet' => ClosetPage,
    'sdb' => SafetyDepositPage
  }
  def build_neopets_page
    type_class = TYPES[params[:type]]

    @neopets_page = type_class.new(current_user)
    @neopets_page.index = params[:index]
    @neopets_page.list_id = params[:list_id]
    @page_params = params[type_class.model_name.singular]
  end

  def on_parse_error(e)
    Rails.logger.info "Neopets page parse error: #{e.message}"
    flash[:alert] = t('neopets_pages.create.parse_error')
    render action: :new
  end
end

