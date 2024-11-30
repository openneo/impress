module SupportFormHelper
	class SupportFormBuilder < ActionView::Helpers::FormBuilder
		attr_reader :template
		delegate :concat, :content_tag, :image_tag, to: :template, private: true

		def errors
			return nil if object.errors.empty?

			error_list = content_tag(:ul) do
				object.errors.each do |error|
					concat content_tag(:li, error.full_message)
				end
			end

			content_tag(:p) do
				concat "Could not save:"
				concat error_list
			end
		end

		def fields(&block)
			content_tag(:ul, class: "fields", &block)
		end

		def field(**kwargs, &block)
			content_tag(:li, **kwargs, &block)
		end

		def radio_fieldset(legend, **kwargs, &block)
			kwargs.reverse_merge!("data-type": "radio")
			field(**kwargs) do
				content_tag(:fieldset) do
					concat content_tag(:legend, legend)
					concat content_tag(:ul, &block)
				end
			end
		end

		def radio_field(**kwargs, &block)
			content_tag(:li) do
				content_tag(:label, **kwargs, &block)
			end
		end

		def radio_grid_fieldset(*args, &block)
			radio_fieldset(*args, "data-type": "radio-grid", &block)
		end

		def thumbnail_input(method)
			url = object.send(method)
			content_tag(:div, class: "thumbnail-input") do
				concat image_tag(url, alt: "Thumbnail") if url.present?
				concat url_field(method)
			end
		end
	end

	def support_form_with(**kwargs, &block)
		kwargs.merge!(
			builder: SupportFormBuilder,
			class: ["support-form", kwargs[:class]],
		)
		form_with(**kwargs, &block)
	end
end
