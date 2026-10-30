{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  packages = with pkgs; [
    fasm    # ассемблер (тот же, что в FASM.zip от преподавателя)
    qemu    # виртуальная машина для проверки загрузчика
    ffmpeg  # конвертация screendump (.ppm) в png для отчёта
  ];
}
