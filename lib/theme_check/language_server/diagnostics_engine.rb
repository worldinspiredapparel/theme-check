# frozen_string_literal: true

module ThemeCheck
  module LanguageServer
    class DiagnosticsEngine
      include URIHelper

      attr_reader :storage

      def initialize(storage, bridge, diagnostics_manager = DiagnosticsManager.new)
        @diagnostics_lock = Mutex.new
        @diagnostics_manager = diagnostics_manager
        @storage = storage
        @bridge = bridge
        @token = 0
      end

      def first_run?
        @diagnostics_manager.first_run?
      end

      def analyze_and_send_offenses(absolute_path, config, force: false)
        return unless @diagnostics_lock.try_lock
        @token += 1
        @bridge.send_create_work_done_progress_request(@token)
        theme = ThemeCheck::Theme.new(storage)
        analyzer = ThemeCheck::Analyzer.new(theme, config.enabled_checks)

        if @diagnostics_manager.first_run? || force
          @bridge.send_work_done_progress_begin(@token, "Full theme check")
          @bridge.log("Checking #{storage.root}")
          offenses = nil
          time = Benchmark.measure do
            offenses = analyzer.analyze_theme do |path, i, total|
              @bridge.send_work_done_progress_report(@token, "#{i}/#{total} #{path}", (i.to_f / total * 100.0).to_i)
            end
          end
          end_message = "Found #{offenses.size} offenses in #{format("%0.2f", time.real)}s"
          @bridge.send_work_done_progress_end(@token, end_message)
          send_diagnostics(offenses)
        else
          # Analyze selected files
          relative_path = Pathname.new(storage.relative_path(absolute_path))
          file = theme[relative_path]
          # Skip if not a theme file
          if file
            @bridge.send_work_done_progress_begin(@token, "Partial theme check")
            offenses = nil
            time = Benchmark.measure do
              offenses = analyzer.analyze_files([file]) do |path, i, total|
                @bridge.send_work_done_progress_report(@token, "#{i}/#{total} #{path}", (i.to_f / total * 100.0).to_i)
              end
            end
            end_message = "Found #{offenses.size} new offenses in #{format("%0.2f", time.real)}s"
            @bridge.send_work_done_progress_end(@token, end_message)
            @bridge.log(end_message)
            send_diagnostics(offenses, [relative_path])
          end
        end
        @diagnostics_lock.unlock
      end

      private

      def send_diagnostics(offenses, analyzed_files = nil)
        @diagnostics_manager.build_diagnostics(offenses, analyzed_files: analyzed_files).each do |relative_path, diagnostics|
          send_diagnostic(relative_path, diagnostics)
        end
      end

      def send_diagnostic(relative_path, diagnostics)
        # https://microsoft.github.io/language-server-protocol/specifications/specification-current/#notificationMessage
        @bridge.send_notification('textDocument/publishDiagnostics', {
          uri: file_uri(storage.path(relative_path)),
          diagnostics: diagnostics.map(&:to_h),
        })
      end
    end
  end
end
