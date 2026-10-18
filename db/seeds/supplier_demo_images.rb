# frozen_string_literal: true

require 'base64'

# Deterministic, valid sample images with no personal or business data.
module SupplierDemoImages
  # Valid, generated Delta POS swatch, never a personal identity photograph.
  JPEG = Base64.decode64(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBAUEBAYFBQUGBgYHCQ4JCQgICRINDQoOFRIWFhUSFBQXGiEcFxgfGRQUHSc' \
    'dHyIjJSUlFhwpLCgkKyEkJST/2wBDAQYGBgkICREJCREkGBQYJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJC' \
    'QkJCQkJCQkJCQkJCT/wAARCAAoACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAA' \
    'gEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6' \
    'Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMX' \
    'Gx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtR' \
    'EAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2N' \
    'zg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6' \
    'wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD6Poorwm9+LniDX5o5l0bUItHeZbd' \
    'ItOmaOSebKMI2nCEknB+WMIxDdTWajc+fr4iNK3N1PY5/E+iW2qppE2q2Ud/J923aUB8/LhcdmO9cA8nsDg1p14zF48fS7K' \
    'Hw+vwomht7rPl2UgY/aSgBLbWhzIwCqSTk8Ak1mW3xJ17wzcyLp/h7U7XTLLy1u9P1CZ50tVYIECuyB4shTgMWX5uFp8jOf' \
    '69BfF+T/wAv67HvNFUtE1H+2NGsNS8ryftltHceXu3bN6hsZwM4z1xRUncndXRdry/4DQRXPgfUIJ4klikv5UeN1DK6mKME' \
    'EHqCO1eoV4F8L/iho3gnQLjTtRttQllku2nDW6Iy7SiLj5mHOVNVFXTOTETjCrBzdlr+h1uv+Ebay8ceDtOttR1aKyka7Mc' \
    'K3bZt1SFPkjk/1iqwUAjdwCdu3NafxP0yz0b4U6hp+n26W9rAsCRxp0A89PzJPJJ5JJJ5rj9Z+MGg6j4s8OaxFaamtvpf2r' \
    'zleNA7eZGFXaN+DyOckfjR49+MGg+KfCd9o9laanHcXHl7GmjQINsisckOT0U9qqz0OaVaio1LNa7fcv1PU/BX/Im6D/2Dr' \
    'b/0UtFHgr/kTdB/7B1t/wCilorNnpU/gXobVFFFBYUUUUAFFFFAH//Z'
  ).freeze

  # Small valid PNG sample for the attachment viewer, not a real identity document.
  PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAIAAAADnC86AAAAqklEQVR42u3Xyw2AIAwGYCBs5GYO4MEB3MyDQ7iEJw8mDeF' \
    'ZKsQY/t4k4qelPNTHdaovwqiPAjDgbEzLLO6rZdPJI/d16w4TSVjY0hjOA7U8C+Y/lH9nAZalkdMrCb+pWC+i/HgLiGUm6s' \
    'm8l7Sw0W3JD5atGqcon3qJlqkm3v0auqyqfCsrUc8WLJlGPEMIE6jYjwEDBtx3dyqeCGRHhvFSrfF/DBjw7+EbA4Ne9CAjj' \
    'xcAAAAASUVORK5CYII='
  ).freeze

  OBSOLETE_JPEG_SHA256 = '8e3a6a63a12cbe868ada81d8602cc6b0d7c881568fff0d08f842dc3939e12e5c'

end
