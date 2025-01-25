### pwd
use lib/pwd.nu *

### proxy
export def proxy_stat [] {
    {|bg|
        let c = $env.NU_POWER_CONFIG.proxy
        if ($env.https_proxy? | is-not-empty) or ($env.http_proxy? | is-not-empty) {
            [$bg '']
        } else {
            [$bg null]
        }
    }
}

### host
def host_abbr [] {
    {|bg|
        let c = $env.NU_POWER_CONFIG.host
        let n = (sys host).hostname
        let ucl = if ($env.SSH_CONNECTION? | is-not-empty) {
                $c.is_remote
            } else {
                $c.default
            }
        let p = if 'ASCIINEMA_REC' in $env {
            $"(ansi xterm_red)⏺ ($env.ASCIINEMA_ID?)"
        } else {
            $"($ucl)($n)"
        }
        [$bg $p]
    }
}

### time
def time_segment [] {
    {|bg|
        let c = $env.NU_POWER_CONFIG.time
        let format = match $c.style {
            "compact" => { $'($c.fst)%y%m%d($c.snd)%w($c.fst)%H%M%S' }
            "rainbow" => {
                let fmt = [w y m d H M S]
                let color = ['1;93m' '1;35m' '1;34m' '1;36m' '1;32m' '1;33m' '1;91m']
                $fmt
                | enumerate
                | each { |x| $"(ansi -e ($color | get $x.index))%($x.item)" }
                | str join
            }
            _  => { $'($c.fst)%y-%m-%d[%w]%H:%M:%S' }
        }
        [$bg $"(date now | format date $format)"]
    }
}

export use lib/profile.nu *

export def wraptime [message action] {
    if $env.NU_POWER_BENCHMARK? == true {
        {|| logtime $message $action }
    } else {
        $action
    }
}

def get_component [schema] {
    let component = $env.NU_PROMPT_COMPONENTS | get $schema.source
    if $env.NU_POWER_BENCHMARK? == true {
        {|bg| logtime $'component ($schema.source)' {|| do $component $bg } }
    } else {
        $component
    }
}

### prompt
def decorator [ ] {
    match $env.NU_POWER_DECORATOR {
        'plain' => {
            {|s, direction?: string, color?: string = 'light_yellow', next_color?: string|
                let dlm = $env.NU_POWER_CONFIG.theme.delimitor
                let dlm = $"(ansi $dlm.color)($dlm.char)"
                match $direction {
                    '|>'|'>' => {
                        let r = $dlm
                        $"($s)($r)"
                    }
                    '>>'|'<<' => {
                        $s
                    }
                    '<' => {
                        let l = $dlm
                        $"($l)($s)"
                    }
                }
            }
        }
        'power' => {
            {|s, direction?: string, color?: string = 'light_yellow', next_color?: string|
                match $direction {
                    '|>' => {
                        let l = (ansi -e {bg: $color})
                        let r = $'(ansi -e {fg: $color, bg: $next_color})(char nf_left_segment)'
                        $'($l)($s)($r)'
                    }
                    '>' => {
                        let r = $'(ansi -e {fg: $color, bg: $next_color})(char nf_left_segment)'
                        $'($s)($r)'
                    }
                    '>>' => {
                        let r = $'(ansi reset)(ansi -e {fg: $color})(char nf_left_segment)'
                        $'($s)($r)'
                    }
                    '<'|'<<' => {
                        let l = $'(ansi -e {fg: $color})(char nf_right_segment)(ansi -e {bg: $color})'
                        $'($l)($s)'
                    }
                }
            }
        }
    }
}

def left_prompt [segment] {
    let decorator = decorator
    let segment = $segment
        | each {|x|
            [$x.color (get_component $x)]
        }
    {||
        let segment = $segment
            | reduce -f [] {|x, acc|
                let y = do $x.1 $x.0
                if $y.1 == null {
                    $acc
                } else {
                    $acc | append [$y]
                }
            }
        let stop = ($segment | length) - 1
        let cs = $segment | each {|x| $x.0 } | append $segment.0.0 | range 1..
        $segment
        | zip $cs
        | enumerate
        | each {|x|
            if $x.index == $stop {
                do $decorator $x.item.0.1 '>>' $x.item.0.0 $x.item.1
            } else if $x.index == 0 {
                do $decorator $x.item.0.1 '|>' $x.item.0.0 $x.item.1
            } else {
                do $decorator $x.item.0.1 '>' $x.item.0.0 $x.item.1
            }
        }
        | str join
    }
}

def right_prompt [segment] {
    let decorator = decorator
    let segment = $segment
        | each {|x|
            [$x.color (get_component $x)]
        }
    {||
        $segment
        | reduce -f [] {|x,acc|
            let y = do $x.1 $x.0
            if $y.1 == null {
                $acc
            } else {
                $acc | append [$y]
            }
        }
        | enumerate
        | each {|x|
            if $x.index == 0 {
                do $decorator $x.item.1 '<<' $x.item.0
            } else {
                do $decorator $x.item.1 '<' $x.item.0
            }
        }
        | str join
    }
}


def 'str len unicode' [--width(-w):int=2] {
    let o = $in
    let a = $o | str length -g
    let u = $o | str replace -a -r $'[^\x00-\x7F($env.NU_POWER_CONFIG.theme.single_width_char)]+' '' | str length -g
    $u + ($a - $u) * $width
}

def 'calc bar width' [-n:int=0] {
    let s = $in
    (term size).columns - ($s | str join '' | ansi strip | str len unicode) - $n
    | if $in > 0 { $in } else { 0 }
}

def up_prompt [segment] {
    let thunk = $segment
    | each {|y| $y | each {|x| get_component $x } }
    { ||
        let sep = $env.NU_POWER_CONFIG.theme.separator_bar
        let d = $env.NU_POWER_CONFIG.theme.delimitor
        let dlm = $"(ansi $d.color)($d.char)"
        let color = $env.NU_POWER_CONFIG.theme.color
        let last_idx = ($thunk | length) - 1
        let ss = $thunk
        | enumerate
        | each {|y|
            $y.item
            | reduce -f [] {|x, acc|
                let y = (do $x null)
                if $y.1 == null {
                    $acc
                } else {
                    $acc | append $y.1
                }
            }
            | str join $dlm
        }
        if ($env.NU_POWER_CONFIG.theme.frame_header? | is-empty) {
            let ss = [$"($ss.0)(ansi $sep.color)($d.right)" $"($d.left)(ansi reset)($ss.1)"]
            let fl = $ss | calc bar width
            $ss | str join $"('' | fill -c $sep.char -w $fl)" | $"($in)\n"
        } else {
            let c = $env.NU_POWER_CONFIG.theme.frame_header
            let color = if (is-admin) { ansi $color.admin } else { ansi $color.normal }
            let ss = [$"($color)($d.left)($ss.0)(ansi $sep.color)($d.right)" $"($d.left)(ansi reset)($ss.1)"]
            let fl = $ss | calc bar width -n $c.upperleft_size
            $ss
            | str join $"('' | fill -c $sep.char -w $fl)"
            | $"($color)($c.upperleft)(ansi reset)($in)\n($color)($c.lowerleft)(ansi reset)"
        }
    }
}

def 'calc sides width' [-n:int=0] {
    let s = $in
    let l = (term size).columns - ($s | str join '' | ansi strip | str len unicode) - $n
    | if $in > 0 { $in } else { 0 }
    | $in / 2
    [($l | math ceil) ($l | math floor)]
}

def up_center_prompt [segment] {
    let thunk = $segment
    | each {|y| $y | each {|x| get_component $x } }
    { ||
        let sep = $env.NU_POWER_CONFIG.theme.separator_bar
        let d = $env.NU_POWER_CONFIG.theme.delimitor
        let dlm = $"(ansi $d.color)($d.char)"
        let color = $env.NU_POWER_CONFIG.theme.color
        let ss = $thunk
        | each {|y|
            $y
            | reduce -f [] {|x, acc|
                let y = (do $x null)
                if $y.1 == null {
                    $acc
                } else {
                    $acc | append $y.1
                }
            }
        }
        | flatten
        | str join $dlm
        if ($env.NU_POWER_CONFIG.theme.frame_header? | is-empty) {
            let ss = $"($d.left)(ansi reset)($ss)(ansi $sep.color)($d.right)"
            let fl = $ss | calc sides width
            [
                $"(ansi $sep.color)('' | fill -c $sep.char -w $fl.0)"
                $ss
                $"('' | fill -c $sep.char -w ($fl.1))(ansi reset)"
            ]
            | str join
            | $"($in)\n"
        } else {
            let c = $env.NU_POWER_CONFIG.theme.frame_header
            let color = if (is-admin) { ansi $color.admin } else { ansi $color.normal }
            let ss = $"($color)($d.left)($ss)($color)($d.right)"
            let fl = $ss | calc sides width -n $c.upperleft_size
            [
                $"($color)($c.upperleft)(ansi reset)"
                $"($color)('' | fill -c $sep.char -w $fl.0)(ansi reset)"
                $ss
                $"($color)('' | fill -c $sep.char -w ($fl.1 - $c.upperright_size))(ansi reset)"
                $"($color)(($c.upperright))\n($c.lowerleft)(ansi reset)"
            ]
            | str join
        }
    }
}

export def default_env [name value] {
    if $name in $env {
        $env | get $name
    } else {
        $value
    }
}

export def --env init [] {
    match $env.NU_POWER_FRAME {
        'default' => {
            $env.PROMPT_COMMAND = (wraptime
                'left'
                (left_prompt $env.NU_POWER_SCHEMA.0)
            )
            $env.PROMPT_COMMAND_RIGHT = (wraptime
                'right'
                (right_prompt $env.NU_POWER_SCHEMA.1)
            )
        }
        'fill' => {
            $env.PROMPT_COMMAND = (up_prompt $env.NU_POWER_SCHEMA)
        }
        'center' => {
            $env.PROMPT_COMMAND = (up_center_prompt $env.NU_POWER_SCHEMA)
        }
    }

    $env.PROMPT_INDICATOR = {||
        let color = $env.NU_POWER_CONFIG.theme.color
        match $env.NU_POWER_DECORATOR {
            'plain' => {
                if (is-admin) {
                    $"(ansi $color.admin)> (ansi reset)"
                } else {
                    $"(ansi $color.normal)> (ansi reset)"
                }
            }
            _ => { " " }
        }
    }
    $env.PROMPT_INDICATOR_VI_INSERT = {|| ": " }
    $env.PROMPT_INDICATOR_VI_NORMAL = {|| "> " }
    $env.PROMPT_MULTILINE_INDICATOR = {||
        match $env.NU_POWER_DECORATOR {
            'plain' => { "::: " }
            _ => { $"(char haze) " }
        }
    }

    if $env.NU_POWER_DECORATOR == 'power' {
        $env.config.menus = $env.config.menus
        | each {|x|
            if ($x.marker in $env.NU_POWER_MENU_MARKER) {
                let c = ($env.NU_POWER_MENU_MARKER | get $x.marker)
                $x | upsert marker $'(ansi -e {fg: $c})(char nf_left_segment_thin) '
            } else {
                $x
            }
        }
    } else {
        $env.config.menus = $env.config.menus
        | each {|x|
            let marker = if $x.marker == '| ' { '┤ ' } else { $x.marker }
            $x | upsert marker (
                if (is-admin) {
                    let adc = $env.NU_POWER_CONFIG.theme.color.admin
                    $"(ansi $adc)($marker)(ansi reset)"
                } else {
                    $marker
                }
            )
        }
    }

    hook
}

export def --env set [name setup] {
    $env.NU_POWER_CONFIG = $env.NU_POWER_CONFIG
    | upsert $name {|x| $x | get -i $name | default {} | merge deep $setup}
}

export def --env register [name source setup] {
    set $name $setup

    $env.NU_PROMPT_COMPONENTS = (
        $env.NU_PROMPT_COMPONENTS | upsert $name {|| $source }
    )
}

export def --env inject [pos idx define setup?] {
    let prev = $env.NU_POWER_SCHEMA | get $pos
    let next = if $idx == 0 {
        $prev | prepend $define
    } else {
        [
            ($prev | range 0..($idx - 1))
            $define
            ($prev | range $idx..)
        ] | flatten
    }

    $env.NU_POWER_SCHEMA = (
        $env.NU_POWER_SCHEMA
        | update $pos $next
    )

    let kind = $define.source


    if ($setup.config? | is-not-empty) {
        let prev_cols = $env.NU_POWER_CONFIG | get $kind | columns
        for n in ($setup.config | transpose k v) {
            if $n.k in $prev_cols {
                $env.NU_POWER_CONFIG = (
                    $env.NU_POWER_CONFIG | update $kind {|conf|
                      $conf | get $kind | update $n.k $n.v
                    }
                )
            }
        }
    }
}

export def --env eject [] {
    "power eject not implement"
}

export def --env hook [] {
    $env.config = ( $env.config | upsert hooks.env_change { |config|
        let init = [{|before, after| if ($before | is-not-empty) { init } }]
        $config.hooks.env_change
        | upsert NU_POWER_SCHEMA $init
        | upsert NU_POWER_FRAME $init
        | upsert NU_POWER_DECORATOR $init
        | upsert NU_POWER_MENU_MARKER $init
        | upsert NU_POWER_BENCHMARK [{ |before, after|
            if ($before | is-not-empty) {
                init
                rm -f ~/.cache/nushell/power_time.log
            }
        }]

    })
}

export-env {
    $env.NU_POWER_BENCHMARK = false

    $env.NU_POWER_SCHEMA = (default_env
        NU_POWER_SCHEMA
        [
            [
                {source: pwd,   color: '#353230'}
            ]
            [
                {source: proxy, color: 'dark_gray'}
                {source: host,  color: '#504945'}
                {source: time,  color: '#353230'}
            ]
        ]
    )

    $env.NU_POWER_FRAME = (default_env
        NU_POWER_FRAME
        'default' # default | fill | center
    )

    $env.NU_POWER_DECORATOR = (default_env
        NU_POWER_DECORATOR
        'power' # power | plain
    )

    $env.NU_POWER_MENU_MARKER = (default_env
        NU_POWER_MENU_MARKER
        {
            "| " : 'green'
            ": " : 'yellow'
            "# " : 'blue'
            "? " : 'red'
        }
    )

    $env.NU_POWER_CONFIG = (default_env
        NU_POWER_CONFIG
        {
            theme: {
                color: {
                    admin: light_red_bold
                    normal: light_cyan
                }
                delimitor: {
                    color: xterm_grey
                    char: '│'
                    left: '┤'
                    right: '├'
                }
                separator_bar: {
                    color: xterm_grey
                    char: '─'
                }
                single_width_char: '↑↓│─├┤'
                frame_header: {
                    upperleft: '┌' # ┌╭
                    upperleft_size: 1
                    lowerleft: '└' # └╰
                    upperright: '┐' # ┐╮
                    upperright_size: 1
                }
            }

            time: {
                style: null
                fst: (ansi xterm_tan)
                snd: (ansi xterm_aqua)
            }
            pwd: {
                default: (ansi xterm_green)
                out_home: (ansi xterm_gold3b)
                vcs: (ansi xterm_teal)
            }
            proxy: {
                on: (ansi yellow)
            }
            host: {
                is_remote: (ansi xterm_red)
                default: (ansi blue)
            }
        }
    )

    $env.NU_PROMPT_COMPONENTS = {
        pwd: (pwd_abbr)
        proxy: (proxy_stat)
        host: (host_abbr)
        time: (time_segment)
    }
}

