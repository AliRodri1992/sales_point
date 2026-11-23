# frozen_string_literal: true

# Original SVG geometries from the approved Delta POS Promotions prototype, version 3.
module DeltaPromotionIconShapes
  SHAPES = {
    'promotion-percent' => 'm5 19 14-14|c:7,7,3|c:17,17,3',
    'promotion-tag' => 'M3 3h9l10 10-9 9L3 12z|c:8,8,1.5',
    'promotion-money' => 'r:2,5,20,14,2|c:12,12,3|M5 12h1m12 0h1',
    'promotion-check' => 'm5 12 4 4L19 6',
    'promotion-calendar' => 'r:3,5,18,16,2|M7 3v4m10-4v4M3 10h18',
    'promotion-pause' => 'M9 5v14M15 5v14',
    'promotion-eye' => 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z|c:12,12,3',
    'promotion-edit' => 'm4 16 12-12 4 4L8 20H4zM13 7l4 4',
    'promotion-trash' => 'M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7',
    'promotion-filter' => 'M4 4h16l-6 8v7l-4 2v-9z',
    'promotion-users' => 'c:9,7,3|M3 20v-3a6 6 0 0 1 12 0v3M16 4a3 3 0 0 1 0 6m2 4a4 4 0 0 1 3 4v2',
    'promotion-clock' => 'c:12,12,9|M12 7v5l3 2',
    'promotion-help' => 'c:12,12,9|M9.1 9a3 3 0 0 1 5.8 1c0 2-3 2.3-3 4m.1 3h.01',
    'promotion-x' => 'm6 6 12 12M18 6 6 18',
    'promotion-plus' => 'M12 5v14M5 12h14',
    'promotion-search' => 'c:10.5,10.5,6.5|m16 16 5 5',
    'promotion-sort' => 'M8 3v17m-4-4 4 4 4-4M16 21V4m-4 4 4-4 4 4',
    'promotion-play' => 'm7 4 14 8-14 8z',
    'promotion-archive' => 'M3 4h18v5H3zM5 9v12h14V9M9 13h6',
    'promotion-copy' => 'r:8,8,13,13,2|M16 8V3H3v13h5',
    'promotion-info' => 'c:12,12,9|M12 11v6m0-10v.5',
    'promotion-chevron-left' => 'm15 18-6-6 6-6',
    'promotion-chevron-right' => 'm9 18 6-6-6-6'
  }.freeze
end
