package com.truthpulse

import android.app.Application
import com.truthpulse.search.SearchService

class TruthPulseApp : Application() {

    lateinit var searchService: SearchService
        private set

    override fun onCreate() {
        super.onCreate()
        searchService = SearchService(this)
    }
}
