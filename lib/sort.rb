def sort_records(records)
  def compare(a, b, key)
    if a[key] && a[key] != b[key]
      a[key] <=> b[key]
    end
  end

  records.sort do |a,b|
    compare(a, b, 'date') ||
    compare(a, b, 'identifier') ||
    compare(a, b, 'position') ||
    compare(a, b, 'organization') ||
    compare(a, b, 'classification') ||
    compare(a, b, 'decision') ||
    compare(b, a, 'number_of_pages') ||
    compare(a, b, 'abstract') ||
    compare(a, b, 'id') ||
    0
  end
end
