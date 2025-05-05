#!/usr/bin/env nextflow

params.prefix = "${params.prefix ?: 'RS08H0'}"

process MDSimulation {
    input:
    val prefix from params.prefix
    path "data/${prefix}_fixed.pdb"

    output:
    path "nvt.xvg"
    path "npt.xvg"

    script:
    """
    chmod +x mds.sh
    ./mds.sh ${prefix}

    echo 15 0 | gmx energy -f nvt.edr -o nvt.xvg
    echo 16 0 | gmx energy -f npt.edr -o npt.xvg
    """
}

process PlotWithR {
    input:
    path "nvt.xvg"
    path "npt.xvg"

    output:
    path "nvt_plot.png"
    path "npt_plot.png"

    script:
    """
    Rscript bin/plot_xvg.R nvt.xvg nvt_plot.png "NVT Temperature"
    Rscript bin/plot_xvg.R npt.xvg npt_plot.png "NPT Pressure"
    """
}

workflow {
    MDSimulation()
    PlotWithR()
}
