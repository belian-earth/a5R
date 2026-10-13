# format shows resolution, cells and stored cells

    Code
      print(disks)
    Output
      <a5_covering[3]>
      [1] res 8: 33 cells (18 stored) res 8: 33 cells (21 stored)
      [3] res 8: 33 cells (15 stored)

# coverings work as tibble columns

    Code
      print(df)
    Output
      # A tibble: 3 x 2
        cell             disk                       
        <a5_cell>        <a5_covering>              
      1 63bb980000000000 res 8: 33 cells (18 stored)
      2 4f0a280000000000 res 8: 33 cells (21 stored)
      3 872fb80000000000 res 8: 33 cells (15 stored)

