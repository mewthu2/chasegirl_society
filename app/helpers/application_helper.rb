module ApplicationHelper
  MONTHS = %w[Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro].freeze

  def brl(value)
    number_to_currency(value.to_d, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  end

  def month_label(date, short: false)
    name = MONTHS[date.month - 1]
    short ? "#{name[0, 3].downcase}/#{date.strftime('%y')}" : "#{name} #{date.year}"
  end

  def month_param(date) = date.strftime("%Y-%m")

  def date_br(date) = date && l(date.to_date, format: "%d/%m/%Y")
  def datetime_br(time) = time && l(time, format: "%d/%m/%Y %H:%M")

  def compact_number(n)
    return "—" if n.blank?
    n = n.to_i
    return "#{(n / 1_000_000.0).round(1).to_s.sub('.0', '').tr('.', ',')}M" if n >= 1_000_000
    return "#{(n / 1_000.0).round(1).to_s.sub('.0', '').tr('.', ',')}k" if n >= 1_000
    n.to_s
  end

  def percent(n) = "#{n.to_d.round(2).to_s('F').sub(/\.0+\z/, '').tr('.', ',')}%"

  def icon(name, **opts)
    tag.i(class: ["fa-solid fa-#{name}", opts[:class]].compact.join(" "), aria: { hidden: true })
  end

  # Selo de situação (tudo em tons de cinza: o "peso" do selo indica a situação).
  def status_chip(status, label = nil)
    icons = {
      "pending" => "hourglass-half", "approved" => "check", "rejected" => "xmark",
      "open" => "clock", "paid" => "check-double", "done" => "ticket", "error" => "triangle-exclamation",
      "none" => "minus", "skipped" => "ban", "met" => "trophy"
    }
    tag.span(class: "chip chip-#{status}") { safe_join([icon(icons.fetch(status, "circle")), label || status]) }
  end

  def channel_icon(kind)
    { "feed" => "table-cells", "stories" => "circle-play", "tiktok" => "music" }.fetch(kind.to_s, "image")
  end

  def progress_bar(value, max, label: nil)
    pct = max.to_i.zero? ? 0 : [(value.to_f / max * 100).round, 100].min
    tag.div(class: "progress #{'is-full' if pct >= 100}", title: label) do
      tag.span(style: "width: #{pct}%")
    end
  end

  def nav_link(label, path, icon_name, active: nil, badge: nil, desc: nil)
    active = current_page?(path) if active.nil?
    link_to path, class: "sb-link#{' is-active' if active}", aria: { current: (active ? "page" : nil) } do
      safe_join([
        icon(icon_name, class: "sb-ic"),
        tag.span(class: "sb-txt") { safe_join([tag.span(label, class: "sb-label"), (tag.span(desc, class: "sb-desc") if desc)].compact) },
        (tag.span(badge, class: "sb-badge") if badge.to_i.positive?)
      ].compact)
    end
  end

  def month_switcher(path_helper, **extra)
    prev_m = selected_month.prev_month
    next_m = selected_month.next_month
    tag.div(class: "month-switch") do
      safe_join([
        link_to(icon("chevron-left"), send(path_helper, extra.merge(mes: month_param(prev_m))), class: "icon-btn", title: month_label(prev_m)),
        tag.span(month_label(selected_month), class: "month-current"),
        link_to(icon("chevron-right"), send(path_helper, extra.merge(mes: month_param(next_m))), class: "icon-btn", title: month_label(next_m))
      ])
    end
  end

  def avatar(text, size: nil)
    tag.span(text, class: ["avatar", size && "avatar-#{size}"].compact.join(" "))
  end

  def media_thumb(attachment)
    if attachment.content_type.to_s.start_with?("video/")
      tag.video(src: url_for(attachment), muted: true, playsinline: true, preload: "metadata")
    else
      image_tag url_for(attachment), alt: attachment.filename.to_s, loading: "lazy"
    end
  end
end
