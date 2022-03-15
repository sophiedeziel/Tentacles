import React from "react";

import { useQuery } from '@apollo/client'

export default function PrintersList() {

  //const { loading, error, data: printersData } = useQuery(Printers);

  // if (error) return(<>Error!{error.message}</>);

  // if (loading) return(<>Loading</>);

  // const {printers} = printersData;

  return (
    <>
      <ul>
        <li>Bulbasaur.gcode</li>
        <li>Temp_Tower.gcode</li>
        <li>untitled.gcode</li>
        <li></li>
      </ul>
    </>
  );
}