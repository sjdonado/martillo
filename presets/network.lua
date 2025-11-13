return {
  {
    id = 'network_copy_ip',
    name = 'Copy IP',
    handler = function()
      spoon.ActionsLauncher.executeShell('curl -s ifconfig.me | pbcopy && curl -s ifconfig.me', 'Copy IP')
    end,
    description = 'Copy public IP address to clipboard',
  },

  {
    id = 'network_speed_test',
    name = 'Network Speed Test',
    description = 'Check network connectivity, latency, and speed',
    handler = function()
      local results = {
        { text = 'Latency: 0%', subText = 'curl to 1.1.1.1' },
        { text = 'Download: 0%', subText = '10MB from speed.cloudflare.com' },
        { text = 'Upload: 0%', subText = '1MB to speed.cloudflare.com' },
      }

      -- Get ActionsLauncher instance
      local actionsLauncher = spoon.ActionsLauncher

      -- Helper to trim whitespace and newlines
      local function trim(s)
        if not s then
          return ''
        end
        return s:match '^%s*(.-)%s*$'
      end

      local function runTests()
        -- Test 1: Latency
        results[1].text = 'Latency: Testing...'
        actionsLauncher:refresh()

        hs.task
          .new('/bin/bash', function(exitCode, stdout, stderr)
            local latency = trim(stdout)
            if exitCode == 0 and latency ~= '' then
              results[1].text = string.format('Latency: %s ms', latency)
            else
              results[1].text = 'Latency: Failed'
            end
            actionsLauncher:refresh()

            -- Test 2: Download
            results[2].text = 'Download: Testing...'
            actionsLauncher:refresh()

            hs.task
              .new('/bin/bash', function(exitCode2, stdout2, stderr2)
                local download = trim(stdout2)
                if exitCode2 == 0 and download ~= '' then
                  results[2].text = string.format('Download: %s MB/s', download)
                else
                  results[2].text = 'Download: Failed'
                end
                actionsLauncher:refresh()

                -- Test 3: Upload
                results[3].text = 'Upload: Testing...'
                actionsLauncher:refresh()

                hs.task
                  .new('/bin/bash', function(exitCode3, stdout3, stderr3)
                    local upload = trim(stdout3)
                    if exitCode3 == 0 and upload ~= '' then
                      results[3].text = string.format('Upload: %s MB/s', upload)
                    else
                      results[3].text = 'Upload: Failed'
                    end
                    actionsLauncher:refresh()
                  end, {
                    '-c',
                    "dd if=/dev/zero bs=1024 count=1024 2>/dev/null | curl -o /dev/null -s -w '%{speed_upload}' --data-binary @- https://speed.cloudflare.com/__up 2>&1 | awk '{printf \"%.2f\", $1 / 1024 / 1024}'",
                  })
                  :start()
              end, {
                '-c',
                "curl -o /dev/null -s -w '%{speed_download}' https://speed.cloudflare.com/__down?bytes=10000000 2>&1 | awk '{printf \"%.2f\", $1 / 1024 / 1024}'",
              })
              :start()
          end, {
            '-c',
            "curl -o /dev/null -s -w '%{time_total}' https://1.1.1.1 2>&1 | awk '{printf \"%.0f\", $1 * 1000}'",
          })
          :start()
      end

      -- Use ActionsLauncher's openChildPicker
      actionsLauncher:openChildPicker {
        placeholder = 'Network test results...',
        parentAction = 'network_status',
        handler = function(query, launcher)
          local choices = {}
          for _, result in ipairs(results) do
            local uuid = launcher:generateUUID()
            table.insert(choices, {
              text = result.text,
              subText = result.subText,
              uuid = uuid,
            })

            -- Empty handler - results are display-only
            launcher.handlers[uuid] = function()
              return ''
            end
          end
          return choices
        end,
      }

      -- Start tests after picker is shown
      hs.timer.doAfter(0.1, runTests)

      return 'OPEN_CHILD_PICKER'
    end,
  },
}
