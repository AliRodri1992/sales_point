# frozen_string_literal: true

module SeedConsole
  class << self
    def start_run!
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      say('INICIO', 'Cargando datos iniciales de Delta POS')
    end

    def track(label, model = nil)
      before = model&.count
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      existing = " (existentes: #{before})" unless before.nil?
      say('INICIO', "Procesando #{label}#{existing}")

      yield

      after = model&.count
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      detail = after.nil? ? '' : " | nuevos: #{after - before} | total: #{after}"
      say('OK', "#{label} finalizado#{detail} | #{format('%.2f', elapsed)}s")
    rescue StandardError => e
      say('ERROR', "#{label}: #{e.class} - #{e.message}")
      raise
    end

    def report(label, model)
      say('INFO', "#{label}: #{model.count} registros")
    end

    def finish_run!
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
      say('FIN', "Carga de seeds terminada en #{format('%.2f', elapsed)}s")
    end

    private

    def say(level, message)
      $stdout.puts("[SEEDS][#{level}] #{message}")
      $stdout.flush
    end
  end
end
