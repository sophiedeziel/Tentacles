import { useMutation } from '@apollo/client/react'
import { App } from 'antd'

import { SET_PRINTER_FAVORITE } from './PrintersList/graphql/fleet'

// The star of the fleet list and the details page's Favorite button: saved on click, not with a form. The
// optimistic answer flips it (and re-sorts the list) at once. Needs an antd <App> ancestor for the errors.
export default function useFavorite ({ id, favorite }) {
  const { message } = App.useApp()
  const [setFavorite] = useMutation(SET_PRINTER_FAVORITE)

  return async () => {
    try {
      const { data } = await setFavorite({
        variables: { id, favorite: !favorite },
        optimisticResponse: {
          setPrinterFavorite: {
            __typename: 'SetPrinterFavoritePayload', printer: { __typename: 'Printer', id, favorite: !favorite }, errors: []
          }
        }
      })
      data.setPrinterFavorite.errors.forEach((error) => message.error(error))
    } catch (error) {
      message.error(`Could not save the favorite: ${error.message}`)
    }
  }
}
