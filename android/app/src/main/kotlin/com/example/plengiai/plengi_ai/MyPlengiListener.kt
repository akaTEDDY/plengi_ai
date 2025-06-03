package com.example.plengiai.plengi_ai

import com.loplat.placeengine.PlengiListener
import com.loplat.placeengine.PlengiResponse

class MyPlengiListener: PlengiListener {
    override fun listen(response: PlengiResponse?) {
        print(response.toString())
    }
}