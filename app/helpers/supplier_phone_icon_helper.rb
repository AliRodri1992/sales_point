# frozen_string_literal: true

module SupplierPhoneIconHelper
  def supplier_phone_icon_name(kind)
    case kind.to_s
    when 'mobile' then 'phone-mobile'
    when 'landline' then 'phone-landline'
    else 'phone'
    end
  end

end
