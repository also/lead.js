output = []
for name, variations of lead.colors.brewer
  output.push "<h3>#{name}</h3>"
  for size, colors of variations
    output.push "<h4 style='margin-top: 1em'>#{size}</h4>" 
    for color in colors
      output.push "<p style='background-color: #{color}'>#{color}</p>"

html output.join('')
