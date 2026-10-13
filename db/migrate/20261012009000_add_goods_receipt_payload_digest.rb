# frozen_string_literal: true

class AddGoodsReceiptPayloadDigest < ActiveRecord::Migration[8.1]
  def change
    add_column :goods_receipts, :payload_digest, :string, limit: 64
  end
end
