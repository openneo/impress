module SupportFormHelper
	class SupportFormBuilder < ActionView::Helpers::FormBuilder
		attr_reader :template
		delegate :capture, :check_box_tag, :content_tag, :params, :render,
			to: :template, private: true

		def errors
			render partial: "application/support_form/errors", locals: {form: self}
		end

		def fields(&block)
			content_tag(:ul, class: "fields", &block)
		end

		def field(**options, &block)
			content_tag(:li, **options, &block)
		end

		def radio_fieldset(legend, **options, &block)
			render partial: "application/support_form/radio_fieldset",
				locals: {form: self, legend:, options:, content: capture(&block)}
		end

		def radio_field(**options, &block)
			content_tag(:li) do
				content_tag(:label, **options, &block)
			end
		end

		def radio_grid_fieldset(*args, &block)
			radio_fieldset(*args, "data-type": "radio-grid", &block)
		end

		def thumbnail_input(method)
			render partial: "application/support_form/thumbnail_input",
				locals: {form: self, method:}
		end

		def actions(&block)
			content_tag(:section, class: "actions", &block)
		end

		def go_to_next_field(**options, &block)
			content_tag(:label, class: "go-to-next", **options, &block)
		end

		def go_to_next_check_box(value)
			check_box_tag "next", value, checked: params[:next] == value
		end
	end

	def support_form_with(**options, &block)
		form_with(
			builder: SupportFormBuilder,
			**options,
			class: ["support-form", options[:class]],
			&block
		)
	end
end
