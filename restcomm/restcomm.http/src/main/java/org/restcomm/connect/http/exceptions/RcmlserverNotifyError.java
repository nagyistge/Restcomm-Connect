/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2014, Telestax Inc and individual contributors
 * by the @authors tag.
 *
 * This program is free software: you can redistribute it and/or modify
 * under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 */

package org.restcomm.connect.http.exceptions;

/**
 * Thrown when notification submission to rcmlserver failed for some reason.
 *
 * @author otsakir@gmail.com - Orestis Tsakiridis
 */
public class RcmlserverNotifyError extends Exception {
    private final boolean critical;

    public RcmlserverNotifyError(String message, boolean critical) {
        super(message);
        this.critical = critical;
    }

    public RcmlserverNotifyError(boolean critical) {
        this.critical = critical;
    }

    public RcmlserverNotifyError(String message, Throwable cause, boolean critical) {
        super(message, cause);
        this.critical = critical;
    }

    public boolean isCritical() {
        return critical;
    }
}