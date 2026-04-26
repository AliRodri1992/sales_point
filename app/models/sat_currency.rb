class SatCurrency < ApplicationRecord
  # =========================
  # VALIDATIONS
  # =========================
  validates :code,
            presence: true,
            uniqueness: { conditions: -> { with_deleted } },
            format: { with: /\A[A-Z]{3}\z/ },
            length: { is: 3 }

  validates :description, presence: true, length: { maximum: 100 }

  validates :decimals, presence: true, inclusion: { in: [0, 2, 3, 4, 5, 6, 8] }

  validates :variation_percentage,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :symbol, length: { maximum: 5 }, allow_nil: true

  # =========================
  # CALLBACKS
  # =========================
  before_validation :normalize_code

  # =========================
  # SCOPES
  # =========================
  scope :ordered, -> { order(:code) }
  scope :by_code, ->(code) { where(code: code.to_s.upcase) }

  def iso_code
    code.to_sym
  end

  def format_amount(amount)
    return nil if amount.nil?

    format("%.#{decimals}f", amount)
  end

  def format_with_symbol(amount)
    prefix = symbol.presence || code
    "#{prefix} #{format_amount(amount)}"
  end

  def fiat?
    symbol.present?
  end

  def base_currency?
    code == 'MXN'
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end
end
