### configuration
```
use power/power.nu
    use power/plugin/git.nu *
    power inject 0 1 {source: git,   color: '#504945'}
    use power/plugin/kube.nu *
    power inject 1 2 {source: kube,  color: '#504945'} {
        theme: {
            context: cyan
        }
        config: {
            reverse: true
            separator: '@'
        }
    }
    power set time {
        config: { style: compact }
    }
power init
```
or
```
## {{{ Simplified style
$env.NU_POWER_SINGLE_WIDTH = '↑↓'
$env.NU_POWER_DECORATOR = 'plain'
$env.NU_POWER_FRAME = 'fill'
$env.NU_POWER_FRAME_HEADER = {
    upperleft: '┌'
    upperleft_size: 1
    lowerleft: '└'
}
## }}}

$env.NU_POWER_SCHEMA = [
    [
        [source, color];
        [pwd, xterm_grey23]
        [git, xterm_grey30]
    ],
    [
        [source, color];
        [proxy, xterm_grey39]
        [host, xterm_grey30]
        [kube, xterm_grey23]
        [time, xterm_grey27]
    ]
]
use power
use power/plugin/git.nu *
use power/plugin/kube.nu *
power set time {
    config: { style: compact }
}
power set kube {
    theme: {
        context: cyan
    }
    config: {
        reverse: true
        separator: '@'
    }
}
power init
```
`$env.NU_POWER_SCHEMA` support configuring dynamically

## mode
- `$env.NU_POWER_DECORATOR = '<power|plain>'` power mode and plain mode
- `$env.NU_POWER_FRAME = '<default|fill>'` two line prompt (experimental)

### benchmark
```
$env.NU_POWER_BENCHMARK = true
```
Then execute a few commands casually, such as pressing the Enter key continuously.
then execute

Execute power timelog to analyze the results.
```
power analyze
```

## todo
- [x] source return `null` for hiding
- [x] proxy stat invalid in plain mode
- [ ] implement `power eject`
- [ ] `$env.config.menus[].maker` can be restored
- [x] support color theme
- [x] refactor: theme/decorator/frame/schema

