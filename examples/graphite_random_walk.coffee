colors = require 'colors'
targets = (randomWalkFunction('test.' + i) for i in [1..9])
graph targets, maxDataPoints: 200, d3_colors: colors.brewer.Set3[11], lineWidth: 1.5, width: 1280, height: 720