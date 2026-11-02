breed [virtual-servers virtual-server]
breed [service-agents service-agent]

virtual-servers-own [
  queue-length
  reservations
]

service-agents-own [
  busy?
  service-timer
  requests-serviced
  current-service-time
  target-server
  idle-ticks
  travel-ticks
  busy-ticks
  task-start-time
  last-task-duration
]

globals [
  avg-queue
  max-queue
  avg-idle
  total-tasks
  avg-utilisation
  dropped-requests
  cumulative-queue-mean
  mean-queue-over-time
]


to setup
  clear-all
  validate-settings

  ; Use a fixed seed for manual runs and different seeds for experiments.
  ifelse behaviorspace-run-number = 0 [
    random-seed 42
  ] [
    random-seed (42 + behaviorspace-run-number)
  ]

  setup-servers
  setup-service-agents
  reset-ticks
  update-stats
  update-charts
end


to validate-settings
  if n-servers < 1 [
    error "n-servers must be at least 1."
  ]
  if n-agents < 0 [
    error "n-agents cannot be negative."
  ]
  if max-queue-limit < 1 [
    error "max-queue-limit must be at least 1."
  ]
  if (request-arrival-prob < 0) or (request-arrival-prob > 1) [
    error "request-arrival-prob must be between 0 and 1."
  ]
  if (service-min-time < 1) or (service-max-time < service-min-time) [
    error "Service times must be positive, with max >= min."
  ]
  if (service-min-time != floor service-min-time) or
     (service-max-time != floor service-max-time) [
    error "Service times must be whole numbers of ticks."
  ]
end


to setup-servers
  let nrows ceiling (sqrt n-servers)
  let ncols ceiling (n-servers / nrows)

  let xspacing (max-pxcor - min-pxcor) / (ncols + 1)
  let yspacing (max-pycor - min-pycor) / (nrows + 1)

  let positions []
  let row 0

  while [row < nrows] [
    let col 0

    while [col < ncols] [
      let xpos min-pxcor + (col + 1) * xspacing
      let ypos min-pycor + (row + 1) * yspacing
      set positions lput (list xpos ypos) positions
      set col col + 1
    ]

    set row row + 1
  ]

  set positions shuffle positions

  foreach (sublist positions 0 n-servers) [ pos ->
    create-virtual-servers 1 [
      setxy (item 0 pos) (item 1 pos)
      set queue-length 0
      set reservations 0
      set shape "square"
      set size 2
      set color blue
      set label queue-length
    ]
  ]
end


to setup-service-agents
  create-service-agents n-agents [
    setxy random-xcor random-ycor
    set busy? false
    set service-timer 0
    set requests-serviced 0
    set current-service-time 0
    set target-server nobody
    set idle-ticks 0
    set travel-ticks 0
    set busy-ticks 0
    set task-start-time 0
    set last-task-duration 0
    set shape "circle"
    set size 1.5
    set color red
    set label "0 / 0"
  ]
end


to go
  generate-requests

  ask service-agents [
    update-service-agent
  ]

  update-labels
  tick
  update-stats
  update-charts
end


to generate-requests
  ask virtual-servers [
    if random-float 1 < request-arrival-prob [
      ifelse queue-length < max-queue-limit [
        set queue-length queue-length + 1
      ] [
        ; Count requests rejected because the queue is full.
        set dropped-requests dropped-requests + 1
      ]
    ]
  ]
end


to update-service-agent
  ifelse busy? [
    process-task
  ] [
    ; Reserve an unclaimed request before travelling to a server.
    if target-server = nobody [
      let available-servers virtual-servers with [queue-length > reservations]

      if any? available-servers [
        set target-server one-of available-servers
        ask target-server [
          set reservations reservations + 1
        ]
      ]
    ]

    ifelse target-server = nobody [
      set idle-ticks idle-ticks + 1
      set color red
    ] [
      ifelse distance target-server > 1 [
        face target-server
        fd 0.2
        set travel-ticks travel-ticks + 1
        set color orange
      ] [
        ; Collect the reserved request and start processing it.
        ask target-server [
          set queue-length queue-length - 1
          set reservations reservations - 1
        ]

        set target-server nobody
        set current-service-time (service-min-time + random (service-max-time - service-min-time + 1))
        set service-timer current-service-time
        set task-start-time ticks
        set busy? true
        set color green
        process-task
      ]
    ]
  ]
end


to process-task
  ; Each processing tick is counted exactly once.
  set busy-ticks busy-ticks + 1
  set service-timer service-timer - 1

  if service-timer <= 0 [
    set busy? false
    set requests-serviced requests-serviced + 1
    set last-task-duration ticks - task-start-time + 1
    set service-timer 0
    set current-service-time 0
    set color red
  ]
end


to update-labels
  ask virtual-servers [
    set label queue-length
  ]

  ask service-agents [
    ; Label shows: last task duration / total tasks completed.
    set label (word last-task-duration " / " requests-serviced)
  ]
end


to update-stats
  set avg-queue mean [queue-length] of virtual-servers
  set max-queue max [queue-length] of virtual-servers

  if any? service-agents [
    set avg-idle mean [idle-ticks] of service-agents
    set total-tasks sum [requests-serviced] of service-agents

    if ticks > 0 [
      set avg-utilisation 100 * (sum [busy-ticks] of service-agents) /
        (ticks * count service-agents)
    ]
  ]

  ; Running average across all completed ticks, for experiments.
  if ticks > 0 [
    set cumulative-queue-mean cumulative-queue-mean + avg-queue
    set mean-queue-over-time cumulative-queue-mean / ticks
  ]
end


to update-charts
  set-current-plot "Average Queue Length"
  set-current-plot-pen "default"
  plotxy ticks avg-queue

  set-current-plot "Maximum Queue Length"
  set-current-plot-pen "default"
  plotxy ticks max-queue
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
60.0

SLIDER
8
13
180
46
n-agents
n-agents
1
50
9.0
1
1
NIL
HORIZONTAL

SLIDER
8
54
180
87
n-servers
n-servers
1
50
9.0
1
1
NIL
HORIZONTAL

SLIDER
10
92
182
125
request-arrival-prob
request-arrival-prob
0
1
0.02
0.01
1
NIL
HORIZONTAL

SLIDER
11
134
183
167
service-min-time
service-min-time
1
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
10
175
182
208
service-max-time
service-max-time
1
20
5.0
1
1
NIL
HORIZONTAL

BUTTON
19
253
82
286
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
93
253
156
286
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
12
290
212
440
Average Queue Length
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
662
34
862
184
Maximum Queue Length
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
699
191
838
236
Total tasks completed
total-tasks
17
1
11

SLIDER
10
216
182
249
max-queue-limit
max-queue-limit
1
50
20.0
1
1
NIL
HORIZONTAL

MONITOR
700
244
835
289
Agent Utilisation (%)
avg-utilisation
1
1
11

MONITOR
709
295
829
340
Rejected Requests
dropped-requests
0
1
11

MONITOR
707
345
834
390
Mean Queue Length
mean-queue-over-time
2
1
11

MONITOR
717
394
823
439
Tasks Per Agent
ifelse-value (count service-agents > 0) [total-tasks / count service-agents] [0]
2
1
11

@#$#@#$#@
## WHAT IS IT?

This model simulates a virtual data centre using autonomous service agents to travel between fixed server queue to process randomly allocated tasks. It investigates how resource allocation, constant incoming workloads and varying processing times influence system performance.

The simulation provides real-time visualisations and performance metrics to monitor server congestion and evaluate processing efficiency under different environmental configurations.

## HOW IT WORKS

The simulation consists of two types of entities:

**Virtual Servers:** Represented by blue squares arranged in a grid. Each server independently receives new requests according to a configurable probability and maintains a queue of outstanding tasks. Requests are rejected when the server reaches its maximum queue capacity.

**Service Agents:** Represented by coloured circles that independently locate servers with outstanding requests. Agents reserve available requests, travel towards their selected server and process tasks over a randomly determined duration.

Agents operate in three states:

* Red: Idle, waiting for available work.
* Orange: Travelling towards an assigned server.
* Green: Processing a request.

Each agent records its completed tasks, processing durations, travelling time and idle time.

## HOW TO USE IT

Adjust the sliders on the Interface tab to configure the simulation:

**n-agents:** Number of autonomous service agents.

**n-servers:** Number of virtual servers.

**request-arrival-prob:** Probability that each server receives a new request during a simulation tick.

**service-min-time:** Minimum request processing duration.

**service-max-time:** Maximum request processing duration.

**max-queue-limit:** Maximum number of requests that can be queued at each server.

Click **Setup** to initialise the simulation using the selected configuration.

Click **Go** to start or stop the simulation.

The interface includes graphs displaying average and maximum server queue lengths, alongside monitors tracking completed tasks, processing utilisation, rejected requests and overall queue congestion.

## THINGS TO NOTICE

Observe how increasing incoming requests affects server queue lengths and the number of rejected requests.

Notice that adding more service agents generally improves processing throughput but eventually produces diminishing returns.

Pay attention to the time agents spend travelling between servers compared with actively processing requests. Excessive movement seems to  restrict throughput even when sufficient processing resources are available.

## THINGS TO TRY

Experiment with different numbers of service agents while keeping the remaining parameters constant.

Increase the request arrival probability to investigate how the system responds when incoming demand exceeds processing capacity.

Increase the minimum and maximum processing times to observe how more demanding tasks influence queue congestion and agent utilisation.

The model includes predefined BehaviorSpace experiments for investigating these relationships systematically.

## EXTENDING THE MODEL

Potential improvements include implementing alternative request allocation strategies, such as 'nearest-server' selection or 'longest-queue-first' scheduling. Comparing these alternative strategies could help identify improvements in throughput and resource utilisation.

Other extensions could introduce task priorities, variable agent movement speeds, server failures and more advanced load-balancing mechanisms to help the simulation better reflect a real data centre.

## CREDITS AND REFERENCES

Developed using NetLogo 6.4.0.

The project's GitHub repository contains the complete simulation, experimental datasets and detailed analysis of the results.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Experiment 1 - Agent Allocation" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>mean-queue-over-time</metric>
    <metric>max-queue</metric>
    <metric>total-tasks</metric>
    <metric>avg-utilisation</metric>
    <metric>dropped-requests</metric>
    <metric>total-tasks / count service-agents</metric>
    <enumeratedValueSet variable="n-agents">
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-servers">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="request-arrival-prob">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-min-time">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-max-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-queue-limit">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment 2 - Workload Scalability" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>mean-queue-over-time</metric>
    <metric>max-queue</metric>
    <metric>total-tasks</metric>
    <metric>avg-utilisation</metric>
    <metric>dropped-requests</metric>
    <metric>total-tasks / count service-agents</metric>
    <enumeratedValueSet variable="n-agents">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-servers">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="request-arrival-prob">
      <value value="0.02"/>
      <value value="0.1"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-min-time">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-max-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-queue-limit">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment 3A - Short Tasks" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>mean-queue-over-time</metric>
    <metric>max-queue</metric>
    <metric>total-tasks</metric>
    <metric>avg-utilisation</metric>
    <metric>dropped-requests</metric>
    <metric>total-tasks / count service-agents</metric>
    <enumeratedValueSet variable="n-agents">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-servers">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="request-arrival-prob">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-min-time">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-max-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-queue-limit">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment 3B - Medium Tasks" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>mean-queue-over-time</metric>
    <metric>max-queue</metric>
    <metric>total-tasks</metric>
    <metric>avg-utilisation</metric>
    <metric>dropped-requests</metric>
    <metric>total-tasks / count service-agents</metric>
    <enumeratedValueSet variable="n-agents">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-servers">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="request-arrival-prob">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-min-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-max-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-queue-limit">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment 3C - Long Tasks" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>mean-queue-over-time</metric>
    <metric>max-queue</metric>
    <metric>total-tasks</metric>
    <metric>avg-utilisation</metric>
    <metric>dropped-requests</metric>
    <metric>total-tasks / count service-agents</metric>
    <enumeratedValueSet variable="n-agents">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-servers">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="request-arrival-prob">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-min-time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-max-time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-queue-limit">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
