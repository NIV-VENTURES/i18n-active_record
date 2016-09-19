#  This extension stores translation stub records for missing translations to
#  the database.
#
#  This is useful if you have a web based translation tool. It will populate
#  the database with untranslated keys as the application is being used. A
#  translator can then go through these and add missing translations.
#
#  Example usage:
#
#     I18n::Backend::Chain.send(:include, I18n::Backend::ActiveRecord::Missing)
#     I18n.backend = I18n::Backend::Chain.new(I18n::Backend::ActiveRecord.new, I18n::Backend::Simple.new)
#
#  Stub records for pluralizations will also be created for each key defined
#  in i18n.plural.keys.
#
#  For example:
#
#    # en.yml
#    en:
#      i18n:
#        plural:
#          keys: [:zero, :one, :other]
#
#    # pl.yml
#    pl:
#      i18n:
#        plural:
#          keys: [:zero, :one, :few, :other]
#
#  It will also persist interpolation keys in Translation#interpolations so
#  translators will be able to review and use them.
module I18n
  module Backend
    class ActiveRecord
      module Missing
        include Flatten

        def store_default_translations(locale, key, options = {})
          count, scope, default, separator, default_locale = options.values_at(:count, :scope, :default, :separator, :default_locale)
          separator ||= I18n.default_separator
          default_locale ||= I18n.default_locale
          key = normalize_flat_keys(locale, key, scope, separator)

          unless ActiveRecord::Translation.locale(locale).lookup(key).exists?
            interpolations = options.keys - I18n::RESERVED_KEYS - [:default_locale]
            plural = I18n.t('i18n.plural.keys', :locale => locale, raise: true) rescue [:zero, :one, :other]
            keys = count && plural.is_a?(Array) ? plural.map { |k| [key, k].join(FLATTEN_SEPARATOR) } : [key]
            keys.each { |key|
              store_default_translation(default_locale, key, interpolations, default) unless ActiveRecord::Translation.locale(default_locale).lookup(key).exists?
              store_default_translation(locale, key, interpolations, nil) if locale.to_sym != default_locale.to_sym
              store_default_translation(I18n.default_locale, key, interpolations, nil) if I18n.default_locale.to_sym != default_locale.to_sym
            }
          end
          default_locale
        end

        def store_default_translation(locale, key, interpolations, default)
          translation = ActiveRecord::Translation.where(:locale => locale.to_s, :key => key).first_or_initialize
          translation.value = cleanup_default(default)
          translation.interpolations = interpolations
          translation.save
        end

        def cleanup_default default
          value = default.is_a?(Array) ? default.first : default
          return nil unless value.is_a?(String)
          value.to_s
        end

        def translate(locale, key, options = {})
          super
        rescue I18n::MissingTranslationData => e
          l = self.store_default_translations(locale, key, options)
          super l, key, options
        end
      end
    end
  end
end

